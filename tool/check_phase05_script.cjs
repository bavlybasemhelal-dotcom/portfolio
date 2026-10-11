// Contract and failure injection for server logic; live Google checks are separate.
const fs = require('node:fs'), path = require('node:path'), vm = require('node:vm'), crypto = require('node:crypto');
const root = path.resolve(__dirname, '..');
const report = { environment: 'Apps Script contract VM with Drive/Firestore fixtures; not live service proof', checks: [], errors: [] };
const files = new Map(), folders = new Map(), documents = new Map();
let counter = 0, receiptFailures = 0, creates = 0;
const iterator = values => { let index = 0; return { hasNext: () => index < values.length, next: () => values[index++] }; };
class Folder {
  constructor(id, name, parent) { this.id = id; this.name = name; this.parent = parent; folders.set(id, this); }
  getId() { return this.id; } getName() { return this.name; }
  getParents() { return iterator(this.parent ? [folders.get(this.parent)] : []); }
  getFoldersByName(name) { return iterator([...folders.values()].filter(f => f.parent === this.id && f.name === name)); }
  createFolder(name) { return new Folder('folder-test-' + (++counter), name, this.id); }
  getFilesByName(name) { return iterator([...files.values()].filter(f => f.parent === this.id && f.name === name && !f.trashed)); }
  createFile(blob) { creates++; return new File('file-test-' + (++counter), blob.name, blob.mime, blob.bytes, this.id); }
}
class File {
  constructor(id, name, mime, bytes, parent) { Object.assign(this, { id, name, mime, bytes, parent, description: '', sharing: 'PRIVATE', trashed: false }); files.set(id, this); }
  getId() { return this.id; } getName() { return this.name; } getMimeType() { return this.mime; } getSize() { return this.bytes.length; }
  getDescription() { return this.description; } setDescription(value) { this.description = value; return this; }
  getParents() { return iterator([folders.get(this.parent)]); } isTrashed() { return this.trashed; }
  setSharing(access) { this.sharing = access; } getSharingAccess() { return this.sharing; }
  getBlob() { return { getBytes: () => [...this.bytes] }; }
}
new Folder('root-folder-1234', 'YOGEN', null);
for (const id of ['projects-folder-1234','brand-folder-1234','team-folder-1234','tests-folder-1234']) new Folder(id, id, 'root-folder-1234');
const typed = value => ({ fields: Object.fromEntries(Object.entries(value).map(([k,v]) => [k, typeof v === 'boolean' ? {booleanValue:v} : typeof v === 'number' ? {integerValue:String(v)} : {stringValue:v}])) });
const response = (code, value) => ({ getResponseCode: () => code, getContentText: () => JSON.stringify(value) });
function identity(token) { try { return JSON.parse(Buffer.from(token.split('.')[1], 'base64url').toString()); } catch (_) { return null; } }
const context = vm.createContext({ console, Date, JSON, Object, String, Number, Error,
  YOGEN_PHASE05_CONFIG: { FIREBASE_API_KEY: 'public-test-key', ROOT_FOLDER_ID:'root-folder-1234', PROJECTS_FOLDER_ID:'projects-folder-1234',
    BRAND_FOLDER_ID:'brand-folder-1234', TEAM_FOLDER_ID:'team-folder-1234', TESTS_FOLDER_ID:'tests-folder-1234', OWNER_UID:'manager' },
  ContentService: { MimeType:{JSON:'JSON'}, createTextOutput: value => ({ value, setMimeType() { return this; } }) },
  PropertiesService: { getScriptProperties: () => ({ getProperties: () => ({}) }) },
  ScriptApp: { getOAuthToken: () => 'server-only-oauth-fixture' },
  LockService: { getScriptLock: () => ({ tryLock: () => true, releaseLock() {} }) },
  DriveApp: { Access: { ANYONE_WITH_LINK:'LINK' }, Permission:{VIEW:'READ'},
    getFolderById: id => { if (!folders.has(id)) throw Error('Missing folder'); return folders.get(id); },
    getFileById: id => { if (!files.has(id)) throw Error('Missing file'); return files.get(id); } },
  Utilities: { DigestAlgorithm:{SHA_256:'sha256'}, base64Decode: v => [...Buffer.from(v,'base64')], base64DecodeWebSafe:v => [...Buffer.from(v,'base64url')],
    base64Encode:v => Buffer.from(v).toString('base64'), computeDigest:(_,v) => [...crypto.createHash('sha256').update(typeof v==='string'?v:Buffer.from(v)).digest()],
    newBlob: (bytes,mime,name) => ({ bytes:Buffer.from(bytes),mime,name,getDataAsString:()=>Buffer.from(bytes).toString() }) },
  UrlFetchApp: { fetch(url, options) {
    if (url.includes('accounts:lookup')) { const p = identity(JSON.parse(options.payload).idToken); return p ? response(200,{users:[{localId:p.sub,disabled:false}]}) : response(400,{}); }
    const key = url.split('/documents/')[1], credential = options.headers.Authorization.replace('Bearer ','');
    const uid = identity(credential)?.sub;
    if (key.includes('/adminUsers/')) {
      const roleUid = key.split('/').at(-1); if (credential !== 'server-only-oauth-fixture' && uid !== roleUid) return response(403,{});
      const role = documents.get(key); return role ? response(200,typed(role)) : response(404,{});
    }
    if (credential !== 'server-only-oauth-fixture') return response(403,{});
    if (options.method === 'patch') {
      if (receiptFailures-- > 0) return response(503,{});
      const fields = JSON.parse(options.payload).fields;
      documents.set(key, Object.fromEntries(Object.entries(fields).map(([k,v]) => [k,context.p5Decode(v)])));
    }
    const value = documents.get(key); return value ? response(200,typed(value)) : response(404,{});
  } }
});
vm.runInContext(fs.readFileSync(path.join(root,'google_drive_script/yogen_phase05.js'),'utf8'),context);
const token = (uid, aud='portfolio-14d15') => 'e30.' + Buffer.from(JSON.stringify({ sub:uid,aud,iss:'https://securetoken.google.com/'+aud,exp:Date.now()/1000+3600,padding:'x'.repeat(120) })).toString('base64url')+'.signature';
documents.set('sites/phase04-test/adminUsers/manager',{role:'manager',enabled:true});
documents.set('sites/phase04-test/adminUsers/editor',{role:'editor',enabled:true});
const png = Buffer.from([137,80,78,71,13,10,26,10,0,0,0,0]);
const body = { action:'upload',site:'phase04-test',scope:'project',projectId:'project-stable',kind:'Images',requestId:'request-00001',
  idToken:token('editor'),fileName:'صورة أفقية.png',mimeType:'image/png',fileData:png.toString('base64'),thumbnailData:png.toString('base64') };
const call = input => JSON.parse(context.doPost({postData:{contents:JSON.stringify(input)}}).value);
const assert = value => { if (!value) throw Error('Contract assertion failed'); };
function check(name, run) { run(); report.checks.push({name,ok:true}); }
try {
  check('P05-T04 anonymous, roleless, wrong-project and revoked identities refused at receiver', () => {
    assert(call({...body,idToken:undefined}).error === 'authentication_required');
    assert(call({...body,idToken:token('roleless')}).error === 'upload_not_allowed');
    assert(call({...body,idToken:token('editor','other-project')}).error === 'wrong_project');
    documents.set('sites/phase04-test/adminUsers/revoked',{role:'editor',enabled:false});
    assert(call({...body,idToken:token('revoked')}).error === 'upload_not_allowed');
  });
  check('P05-T03 server checks MIME, signature and >5 MiB before Drive creation', () => {
    assert(call({...body,mimeType:'text/html'}).error === 'unsupported_type');
    assert(call({...body,fileData:Buffer.from('incorrect').toString('base64')}).error === 'signature_mismatch');
    const large = Buffer.concat([png,Buffer.alloc(5*1024*1024+1-png.length)]);
    assert(call({...body,fileData:large.toString('base64')}).error === 'file_too_large'); assert(creates === 0);
  });
  let uploaded;
  check('P05-T02 stable project directories, Arabic metadata, real file and thumbnail receipts', () => {
    uploaded = call(body); assert(uploaded.success && uploaded.fileName === body.fileName && uploaded.projectId === 'project-stable');
    assert(uploaded.thumbnailFileId && uploaded.folderId && uploaded.sha256); assert(creates === 2);
    assert(folders.get(uploaded.folderId).name === 'Images');
  });
  check('P05-T05 repeated request reuses original and thumbnail', () => { assert(call(body).fileId === uploaded.fileId); assert(creates === 2); });
  check('Same request with changed content, filename, target or thumbnail rejected', () => {
    assert(call({...body,fileName:'different.png'}).error === 'request_conflict');
    assert(call({...body,projectId:'other-project'}).error === 'request_conflict');
    assert(call({...body,thumbnailData:undefined}).error === 'request_conflict');
  });
  check('P05-T06 unknown outcome reconciles by status before resend', () => {
    const lost = {...body,requestId:'request-lost-01'}; receiptFailures = 1;
    const failed = call(lost); if (failed.error !== 'database_unavailable') throw Error('Expected receipt failure: ' + JSON.stringify({success:failed.success,error:failed.error})); const before = creates;
    const recovered = call({...lost,action:'upload_status',fileData:undefined,thumbnailData:undefined});
    if (!(recovered.success && recovered.found && recovered.fileId)) throw Error('Status failed: ' + JSON.stringify({success:recovered.success,found:recovered.found,error:recovered.error})); assert(creates === before);
    assert(call({...lost,action:'upload_status',requestId:'never-sent-001'}).found === false);
  });
  check('P05-T08 anonymous reads are receipt-bounded and preserve original bytes', () => {
    const read = call({action:'read',site:'phase04-test',assetId:uploaded.assetId}); assert(read.success && Buffer.from(read.fileData,'base64').equals(png));
    assert(call({action:'read',site:'phase04-test',assetId:'m_'+'f'.repeat(64)}).error === 'not_public_media');
    assert(call({action:'read',site:'yogen',assetId:uploaded.assetId}).error === 'not_public_media');
  });
  check('Moved or trashed files fail safely; restoration keeps same reference', () => {
    const file = files.get(uploaded.fileId); file.trashed=true; assert(call({action:'read',site:'phase04-test',assetId:uploaded.assetId}).error==='not_public_media');
    file.trashed=false; assert(call({action:'read',site:'phase04-test',assetId:uploaded.assetId}).success);
  });
} catch(e) { report.errors.push(e.message); process.exitCode=1; }
fs.writeFileSync(path.join(root,'phases/results/05/checks/script-contract.json'),JSON.stringify(report,null,2));
console.log(JSON.stringify({checks:report.checks.length,errors:report.errors.length}));
