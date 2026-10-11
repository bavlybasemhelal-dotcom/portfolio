/** YOGEN isolated media experiment. Production roles belong to phase 04. */
const YOGEN_PROJECT = 'portfolio-14d15';
const YOGEN_TYPES = ['image/png', 'image/jpeg', 'image/webp', 'video/mp4', 'video/webm', 'application/pdf'];
const YOGEN_LIMIT = 5 * 1024 * 1024; // Experiment guardrail, not a proven upload limit.
let YOGEN_STAGE = 'request';

function failure(code) { throw new Error(code); }
function output(value) {
  return ContentService.createTextOutput(JSON.stringify(value)).setMimeType(ContentService.MimeType.JSON);
}
function properties() {
  const p = Object.assign({}, typeof YOGEN_PHASE03_CONFIG === 'undefined' ? {} : YOGEN_PHASE03_CONFIG,
    PropertiesService.getScriptProperties().getProperties());
  if (!p.FIREBASE_API_KEY || !p.TEST_FOLDER_ID || !p.ROOT_FOLDER_ID || !p.ALLOWED_UIDS) failure('server_not_configured');
  return p;
}
function doGet() { return output({success: false, error: 'post_required'}); }
function doPost(e) {
  try {
    const raw = e && e.postData && e.postData.contents;
    if (!raw || raw.length > Math.ceil(YOGEN_LIMIT / 3) * 4 + 16384) failure('request_too_large');
    let request;
    try { request = JSON.parse(raw); } catch (_) { failure('invalid_json'); }
    const p = properties();
    if (request.action === 'image') return output(readPublicImage(request, p));
    if (request.action === 'video') return output(readPublicImage(request, p, ['video/mp4','video/webm']));
    const uid = authenticate(request.idToken, p);
    if (request.action === 'ping') {
      assertTestFolder(p);
      return output({success: true, projectId: YOGEN_PROJECT, testOnly: true, maxTestBytes: YOGEN_LIMIT});
    }
    if (request.action !== 'upload') failure('unknown_action');
    return output(upload(request, p, uid));
  } catch (error) {
    // Never log requests, credentials, ID tokens, or upstream exception bodies.
    const allowed = ['server_not_configured','request_too_large','invalid_json','authentication_required',
      'invalid_identity','wrong_project','upload_not_allowed','unknown_action','test_folder_mismatch',
      'invalid_request_id','invalid_filename','unsupported_type','invalid_base64','unverified_size',
      'empty_file','signature_mismatch','busy_retry','sharing_failed','invalid_file_id','not_public_test_image',
      'request_conflict'];
    const diagnostic = String(error.message || '').indexOf('Argument too large') >= 0 ? 'argument_too_large'
      : String(error.message || '').indexOf('Maximum call stack') >= 0 ? 'call_stack_limit' : 'bridge_failure';
    return output({success: false, error: allowed.indexOf(error.message) >= 0 ? error.message : diagnostic,
      stage: YOGEN_STAGE});
  }
}
function authenticate(token, p) {
  if (typeof token !== 'string' || token.length < 100 || token.length > 10000) failure('authentication_required');
  // Google's Auth backend validates signature, expiry and project API key first.
  const response = UrlFetchApp.fetch('https://identitytoolkit.googleapis.com/v1/accounts:lookup?key=' + encodeURIComponent(p.FIREBASE_API_KEY), {
    method: 'post', contentType: 'application/json', payload: JSON.stringify({idToken: token}), muteHttpExceptions: true,
  });
  if (response.getResponseCode() !== 200) failure('invalid_identity');
  let payload, user;
  try {
    user = JSON.parse(response.getContentText()).users[0];
    payload = JSON.parse(Utilities.newBlob(Utilities.base64DecodeWebSafe(token.split('.')[1])).getDataAsString());
  } catch (_) { failure('invalid_identity'); }
  if (!user || user.disabled || !user.localId || payload.sub !== user.localId) failure('invalid_identity');
  if (payload.aud !== YOGEN_PROJECT || payload.iss !== 'https://securetoken.google.com/' + YOGEN_PROJECT || payload.exp * 1000 <= Date.now()) failure('wrong_project');
  const allowed = p.ALLOWED_UIDS.split(',').map(value => value.trim()).filter(Boolean);
  if (allowed.indexOf(user.localId) < 0) failure('upload_not_allowed');
  return user.localId;
}
function assertTestFolder(p) {
  const folder = DriveApp.getFolderById(p.TEST_FOLDER_ID);
  const parents = folder.getParents();
  let valid = false;
  while (parents.hasNext()) if (parents.next().getId() === p.ROOT_FOLDER_ID) valid = true;
  if (!valid) failure('test_folder_mismatch');
  return folder;
}
function bytesMatch(bytes, mime) {
  // Inspect only the signature; mapping the entire video duplicates a large byte array.
  const u = bytes.slice(0, 16).map(v => (v + 256) % 256);
  const text = (start, count) => u.slice(start, start + count).map(v => String.fromCharCode(v)).join('');
  if (mime === 'image/png') return u.length > 8 && [137,80,78,71,13,10,26,10].every((v, i) => u[i] === v);
  if (mime === 'image/jpeg') return u[0] === 255 && u[1] === 216 && u[2] === 255;
  if (mime === 'image/webp') return text(0,4) === 'RIFF' && text(8,4) === 'WEBP';
  if (mime === 'video/mp4') return text(4,4) === 'ftyp';
  if (mime === 'video/webm') return [26,69,223,163].every((v, i) => u[i] === v);
  if (mime === 'application/pdf') return text(0,5) === '%PDF-';
  return false;
}
function result(file) {
  const id = file.getId();
  return {success: true, projectId: YOGEN_PROJECT, testOnly: true,
    fileId: id, fileName: file.getName(), fileSize: file.getSize(), mimeType: file.getMimeType(),
    directUrl: 'https://drive.google.com/uc?export=view&id=' + id,
    viewUrl: 'https://drive.google.com/file/d/' + id + '/view',
    downloadUrl: 'https://drive.google.com/uc?export=download&id=' + id};
}
function upload(r, p, uid) {
  if (r.category !== 'phase03') failure('upload_not_allowed');
  if (typeof r.requestId !== 'string' || !/^[a-zA-Z0-9_-]{8,100}$/.test(r.requestId)) failure('invalid_request_id');
  if (typeof r.fileName !== 'string' || !r.fileName.trim() || r.fileName.length > 180 || /[\x00-\x1f\/\\]/.test(r.fileName)) failure('invalid_filename');
  if (YOGEN_TYPES.indexOf(r.mimeType) < 0) failure('unsupported_type');
  // Avoid a nested repeating regex: multi-MiB Base64 can overflow its stack.
  if (typeof r.fileData !== 'string' || r.fileData.length % 4 !== 0 ||
      /[^A-Za-z0-9+/=]/.test(r.fileData) || /=[^=]/.test(r.fileData) ||
      (r.fileData.indexOf('=') >= 0 && r.fileData.indexOf('=') < r.fileData.length - 2)) failure('invalid_base64');
  if (r.fileData.length > Math.ceil(YOGEN_LIMIT / 3) * 4) failure('unverified_size');
  YOGEN_STAGE = 'base64_decode';
  const bytes = Utilities.base64Decode(r.fileData);
  if (!bytes.length) failure('empty_file');
  if (bytes.length > YOGEN_LIMIT) failure('unverified_size');
  if (!bytesMatch(bytes, r.mimeType)) failure('signature_mismatch');
  YOGEN_STAGE = 'folder';
  const folder = assertTestFolder(p);
  const lock = LockService.getScriptLock();
  if (!lock.tryLock(10000)) failure('busy_retry');
  try {
    // Find the unique request tag in the isolated folder, without growing script properties.
    const tag = 'YOGEN_PHASE03:' + uid + ':' + r.requestId;
    YOGEN_STAGE = 'digest';
    const hash = Utilities.base64Encode(Utilities.computeDigest(Utilities.DigestAlgorithm.SHA_256, bytes));
    const expected = {tag: tag, projectId: YOGEN_PROJECT, testOnly: true, public: true, sha256: hash, mime: r.mimeType};
    const existing = folder.getFiles();
    while (existing.hasNext()) {
      const file = existing.next();
      let data;
      try { data = JSON.parse(file.getDescription()); } catch (_) { continue; }
      if (data.tag === tag) {
        if (data.sha256 !== hash || file.getName() !== r.fileName || data.mime !== r.mimeType) failure('request_conflict');
        // Retry can recover a previous sharing failure, without creating another file.
        publish(file);
        return result(file);
      }
    }
    YOGEN_STAGE = 'create_file';
    const file = folder.createFile(Utilities.newBlob(bytes, r.mimeType, r.fileName));
    file.setDescription(JSON.stringify(expected));
    publish(file);
    return result(file);
  } finally { lock.releaseLock(); }
}
function publish(file) {
  try {
    file.setSharing(DriveApp.Access.ANYONE_WITH_LINK, DriveApp.Permission.VIEW);
    if (file.getSharingAccess() !== DriveApp.Access.ANYONE_WITH_LINK) failure('sharing_failed');
  } catch (_) { failure('sharing_failed'); }
}
function readPublicImage(r, p, allowedTypes) {
  allowedTypes = allowedTypes || ['image/png','image/jpeg','image/webp'];
  if (typeof r.fileId !== 'string' || !/^[\w-]{10,}$/.test(r.fileId)) failure('invalid_file_id');
  assertTestFolder(p);
  const file = DriveApp.getFileById(r.fileId);
  const parents = file.getParents();
  let inTests = false, data;
  while (parents.hasNext()) if (parents.next().getId() === p.TEST_FOLDER_ID) inTests = true;
  try { data = JSON.parse(file.getDescription()); } catch (_) { failure('not_public_test_image'); }
  if (!inTests || data.projectId !== YOGEN_PROJECT || data.testOnly !== true || data.public !== true ||
      file.getSharingAccess() !== DriveApp.Access.ANYONE_WITH_LINK ||
      allowedTypes.indexOf(file.getMimeType()) < 0 || file.getSize() > YOGEN_LIMIT) failure('not_public_test_image');
  return {success: true, mimeType: file.getMimeType(), fileData: Utilities.base64Encode(file.getBlob().getBytes())};
}
