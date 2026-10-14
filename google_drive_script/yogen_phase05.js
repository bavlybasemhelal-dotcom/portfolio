/** YOGEN media bridge: validated Firebase roles, immutable server receipts. */
const P5_PROJECT = 'portfolio-14d15';
const P5_LIMIT = 5 * 1024 * 1024;
const P5_THUMB_LIMIT = 200 * 1024;
const P5_TYPES = ['image/png', 'image/jpeg', 'image/webp', 'video/mp4', 'video/webm', 'application/pdf'];
function p5Fail(code) { throw new Error(code); }
function p5Output(value) { return ContentService.createTextOutput(JSON.stringify(value)).setMimeType(ContentService.MimeType.JSON); }
function p5Config() {
  const p = Object.assign({}, YOGEN_PHASE05_CONFIG, PropertiesService.getScriptProperties().getProperties());
  if (!p.FIREBASE_API_KEY || !p.ROOT_FOLDER_ID || !p.PROJECTS_FOLDER_ID || !p.TESTS_FOLDER_ID) p5Fail('server_not_configured');
  return p;
}
function doGet() { return p5Output({ success: false, error: 'post_required', version: 5 }); }
// Run once in the editor if Google requires consent for the added datastore scope.
function authorizeMediaBackend() {
  // The editor may retain a partial grant when new scopes are added.
  ScriptApp.requireAllScopes(ScriptApp.AuthMode.FULL);
  const p = p5Config();
  DriveApp.getFolderById(p.ROOT_FOLDER_ID).getName();
  p5Database('sites/yogen/adminUsers/' + p.OWNER_UID, null, null);
  return { success: true };
}
function doPost(e) {
  try {
    const raw = e && e.postData && e.postData.contents;
    if (!raw || raw.length > Math.ceil((P5_LIMIT + P5_THUMB_LIMIT) / 3) * 4 + 20000) p5Fail('request_too_large');
    let r; try { r = JSON.parse(raw); } catch (_) { p5Fail('invalid_json'); }
    const p = p5Config();
    p5Site(r.site);
    if (r.action === 'read') return p5Output(p5Read(r, p));
    const member = p5Authenticate(r.idToken, r.site, p);
    if (r.action === 'ping') {
      // Prove Drive and server receipt access before accepting connection settings.
      const root = DriveApp.getFolderById(p.ROOT_FOLDER_ID);
      p5Database('sites/' + r.site + '/adminUsers/' + member.uid, null, null);
      return p5Output({ success: true, version: 5, projectId: P5_PROJECT, rootFolderId: root.getId(), rootFolderName: root.getName(), maxBytes: P5_LIMIT });
    }
    if (!['upload', 'upload_status'].includes(r.action)) p5Fail('unknown_action');
    p5ValidateTarget(r);
    const lock = LockService.getScriptLock();
    if (!lock.tryLock(10000)) p5Fail('busy_retry');
    try { return p5Output(p5Upload(r, p, member)); } finally { lock.releaseLock(); }
  } catch (e) {
    const codes = ['server_not_configured','request_too_large','invalid_json','invalid_site','authentication_required',
      'invalid_identity','wrong_project','upload_not_allowed','unknown_action','invalid_project_id','invalid_scope',
      'invalid_request_id','invalid_filename','unsupported_type','invalid_base64','file_too_large','empty_file',
      'signature_mismatch','busy_retry','sharing_failed','request_conflict','database_unavailable','receipt_unavailable',
      'folder_mismatch','invalid_asset_id','not_public_media','invalid_thumbnail','backend_scope_required','backend_permission_required'];
    return p5Output({ success: false, error: codes.includes(e.message) ? e.message : 'bridge_failure' });
  }
}
function p5Site(site) { if (!['yogen', 'phase04-test'].includes(site)) p5Fail('invalid_site'); }
function p5Authenticate(token, site, p) {
  if (typeof token !== 'string' || token.length < 100 || token.length > 10000) p5Fail('authentication_required');
  const response = UrlFetchApp.fetch('https://identitytoolkit.googleapis.com/v1/accounts:lookup?key=' + encodeURIComponent(p.FIREBASE_API_KEY), {
    method: 'post', contentType: 'application/json', payload: JSON.stringify({ idToken: token }), muteHttpExceptions: true });
  if (response.getResponseCode() !== 200) p5Fail('invalid_identity');
  let user, payload;
  try {
    user = JSON.parse(response.getContentText()).users[0];
    payload = JSON.parse(Utilities.newBlob(Utilities.base64DecodeWebSafe(token.split('.')[1])).getDataAsString());
  } catch (_) { p5Fail('invalid_identity'); }
  if (!user || user.disabled || !user.localId || payload.sub !== user.localId
      || (user.validSince && (!payload.auth_time || payload.auth_time < Number(user.validSince)))) p5Fail('invalid_identity');
  if (payload.aud !== P5_PROJECT || payload.iss !== 'https://securetoken.google.com/' + P5_PROJECT || payload.exp * 1000 <= Date.now()) p5Fail('wrong_project');
  const role = p5Database('sites/' + site + '/adminUsers/' + user.localId, token, null);
  if (!role || role.enabled !== true || !['manager','editor'].includes(role.role)) p5Fail('upload_not_allowed');
  return { uid: user.localId, role: role.role };
}
function p5Decode(v) {
  if ('stringValue' in v) return v.stringValue;
  if ('integerValue' in v) return Number(v.integerValue);
  if ('booleanValue' in v) return v.booleanValue;
  if ('timestampValue' in v) return v.timestampValue;
  return null;
}
function p5Database(path, userToken, value) {
  const options = { method: value ? 'patch' : 'get', muteHttpExceptions: true,
    headers: { Authorization: 'Bearer ' + (userToken || ScriptApp.getOAuthToken()) } };
  if (value) {
    const fields = {};
    Object.keys(value).forEach(key => {
      const v = value[key]; fields[key] = typeof v === 'boolean' ? { booleanValue: v }
        : typeof v === 'number' ? { integerValue: String(v) } : { stringValue: String(v) };
    });
    options.contentType = 'application/json'; options.payload = JSON.stringify({ fields: fields });
  }
  const response = UrlFetchApp.fetch('https://firestore.googleapis.com/v1/projects/' + P5_PROJECT + '/databases/(default)/documents/' + path, options);
  if (!value && response.getResponseCode() === 404) return null;
  if (response.getResponseCode() !== 200) {
    if (userToken) p5Fail('upload_not_allowed');
    let error; try { error = JSON.parse(response.getContentText()).error || {}; } catch (_) { error = {}; }
    const reasons = (error.details || []).map(v => v.reason);
    if (reasons.includes('ACCESS_TOKEN_SCOPE_INSUFFICIENT')) p5Fail('backend_scope_required');
    if (response.getResponseCode() === 403) p5Fail('backend_permission_required');
    p5Fail('database_unavailable');
  }
  const fields = JSON.parse(response.getContentText()).fields || {}, result = {};
  Object.keys(fields).forEach(key => { result[key] = p5Decode(fields[key]); });
  return result;
}
function p5Hash(bytes) { return Utilities.computeDigest(Utilities.DigestAlgorithm.SHA_256, bytes).map(v => ('0' + ((v + 256) % 256).toString(16)).slice(-2)).join(''); }
function p5AssetId(r, uid) { return 'm_' + p5Hash(r.site + ':' + uid + ':' + r.requestId); }
function p5ValidateTarget(r) {
  if (!['project','brand','team'].includes(r.scope)) p5Fail('invalid_scope');
  if (typeof r.projectId !== 'string' || !/^[A-Za-z0-9_-]{1,70}$/.test(r.projectId)) p5Fail('invalid_project_id');
  if (typeof r.requestId !== 'string' || !/^[A-Za-z0-9_-]{8,100}$/.test(r.requestId)) p5Fail('invalid_request_id');
}
function p5Folder(parent, name, create) {
  const folders = parent.getFoldersByName(name);
  if (folders.hasNext()) return folders.next();
  return create ? parent.createFolder(name) : null;
}
function p5Target(r, p, create) {
  let parent = DriveApp.getFolderById(r.site === 'phase04-test' ? p.TESTS_FOLDER_ID
    : r.scope === 'brand' ? p.BRAND_FOLDER_ID : r.scope === 'team' ? p.TEAM_FOLDER_ID : p.PROJECTS_FOLDER_ID);
  const ancestors = parent.getParents(); let underRoot = false;
  while (ancestors.hasNext()) if (ancestors.next().getId() === p.ROOT_FOLDER_ID) underRoot = true;
  if (!underRoot) p5Fail('folder_mismatch');
  if (r.site === 'phase04-test') parent = p5Folder(parent, r.scope, create);
  if (!parent) return null;
  parent = p5Folder(parent, r.projectId, create); if (!parent) return null;
  return p5Folder(parent, r.kind, create);
}
function p5Signature(bytes, mime) {
  const u = bytes.slice(0, 16).map(v => (v + 256) % 256);
  const text = (start, count) => u.slice(start, start + count).map(v => String.fromCharCode(v)).join('');
  if (mime === 'image/png') return [137,80,78,71,13,10,26,10].every((v,i) => u[i] === v);
  if (mime === 'image/jpeg') return u[0] === 255 && u[1] === 216 && u[2] === 255;
  if (mime === 'image/webp') return text(0,4) === 'RIFF' && text(8,4) === 'WEBP';
  if (mime === 'video/mp4') return text(4,4) === 'ftyp';
  if (mime === 'video/webm') return [26,69,223,163].every((v,i) => u[i] === v);
  return mime === 'application/pdf' && text(0,5) === '%PDF-';
}
function p5Bytes(data, mime, limit) {
  if (typeof data !== 'string' || data.length % 4 !== 0 || /[^A-Za-z0-9+/=]/.test(data)
      || /=[^=]/.test(data) || (data.indexOf('=') >= 0 && data.indexOf('=') < data.length - 2)) p5Fail('invalid_base64');
  if (data.length > Math.ceil(limit / 3) * 4) p5Fail('file_too_large');
  const bytes = Utilities.base64Decode(data);
  if (!bytes.length) p5Fail('empty_file');
  if (bytes.length > limit) p5Fail('file_too_large');
  if (!p5Signature(bytes, mime)) p5Fail('signature_mismatch');
  return bytes;
}
function p5Share(file) {
  try { file.setSharing(DriveApp.Access.ANYONE_WITH_LINK, DriveApp.Permission.VIEW);
    if (file.getSharingAccess() !== DriveApp.Access.ANYONE_WITH_LINK) p5Fail('sharing_failed');
  } catch (_) { p5Fail('sharing_failed'); }
}
function p5Upload(r, p, member) {
  if (!['Images','Videos','Attachments'].includes(r.kind)) p5Fail('invalid_scope');
  const id = p5AssetId(r, member.uid), path = 'sites/' + r.site + '/mediaReceipts/' + id;
  const prior = p5Database(path, null, null);
  if (prior && (prior.scope !== r.scope || prior.projectId !== r.projectId || prior.kind !== r.kind)) p5Fail('request_conflict');
  let bytes, hash, thumbnail;
  if (r.action === 'upload') {
    if (typeof r.fileName !== 'string' || !r.fileName.trim() || r.fileName.length > 180 || /[\x00-\x1f\/\\]/.test(r.fileName)) p5Fail('invalid_filename');
    if (!P5_TYPES.includes(r.mimeType)) p5Fail('unsupported_type');
    const kind = r.mimeType.startsWith('image/') ? 'Images' : r.mimeType.startsWith('video/') ? 'Videos' : 'Attachments';
    if (kind !== r.kind) p5Fail('invalid_scope');
    bytes = p5Bytes(r.fileData, r.mimeType, P5_LIMIT); hash = p5Hash(bytes);
    if (r.thumbnailData) {
      if (!r.mimeType.startsWith('image/')) p5Fail('invalid_thumbnail');
      thumbnail = p5Bytes(r.thumbnailData, 'image/png', P5_THUMB_LIMIT);
    }
    if (prior && (prior.sha256 !== hash || prior.fileName !== r.fileName || prior.mimeType !== r.mimeType
      || prior.thumbnailSha256 !== (thumbnail ? p5Hash(thumbnail) : ''))) p5Fail('request_conflict');
  }
  if (prior) { p5VerifyFile(prior, p); return Object.assign({ success: true, found: true }, prior); }
  const folder = p5Target(r, p, r.action === 'upload');
  if (!folder) return { success: true, found: false };
  const marker = { assetId: id, site: r.site, projectId: r.projectId, scope: r.scope, kind: r.kind,
    uploadedBy: member.uid, requestId: r.requestId };
  let file = null, meta;
  // Stable file name exists even if execution was interrupted before setDescription.
  const existing = folder.getFilesByName(id + '.original');
  if (existing.hasNext()) {
    file = existing.next();
    try { meta = JSON.parse(file.getDescription()); } catch (_) {
      if (r.action === 'upload_status') return { success: true, found: false, retrySameRequest: true };
      if (p5Hash(file.getBlob().getBytes()) !== hash || file.getMimeType() !== r.mimeType) p5Fail('request_conflict');
    }
    if (meta && (meta.assetId !== id || meta.uploadedBy !== member.uid)) p5Fail('request_conflict');
    if (r.action === 'upload' && meta && (meta.sha256 !== hash || meta.fileName !== r.fileName || meta.mimeType !== r.mimeType
      || meta.thumbnailSha256 !== (thumbnail ? p5Hash(thumbnail) : ''))) p5Fail('request_conflict');
  }
  if (!file && r.action === 'upload_status') return { success: true, found: false };
  if (!file) file = folder.createFile(Utilities.newBlob(bytes, r.mimeType, id + '.original'));
  if (!meta) {
    meta = Object.assign({}, marker, { sha256: hash, fileName: r.fileName, mimeType: r.mimeType,
      fileSize: file.getSize(), fileId: file.getId(), folderId: folder.getId(),
      thumbnailSha256: thumbnail ? p5Hash(thumbnail) : '', thumbnailFileId: '', public: true });
    file.setDescription(JSON.stringify(meta));
  }
  if (meta.thumbnailSha256 && !meta.thumbnailFileId) {
    const thumbnails = folder.getFilesByName(id + '.thumbnail.png');
    let thumb = thumbnails.hasNext() ? thumbnails.next() : null;
    if (!thumb && !thumbnail) return { success: true, found: false, retrySameRequest: true };
    if (!thumb) thumb = folder.createFile(Utilities.newBlob(thumbnail, 'image/png', id + '.thumbnail.png'));
    if (p5Hash(thumb.getBlob().getBytes()) !== meta.thumbnailSha256) p5Fail('request_conflict');
    thumb.setDescription(JSON.stringify({ assetId: id, site: r.site, thumbnail: true }));
    p5Share(thumb); meta.thumbnailFileId = thumb.getId(); file.setDescription(JSON.stringify(meta));
  }
  p5Share(file);
  // Only the authenticated script owner can write receipts (IAM), never client roles.
  const receipt = Object.assign({}, meta, { viewUrl: 'https://drive.google.com/file/d/' + file.getId() + '/view',
    downloadUrl: 'https://drive.google.com/uc?export=download&id=' + file.getId(),
    directUrl: 'https://drive.google.com/uc?export=view&id=' + file.getId() });
  p5Database(path, null, receipt);
  return Object.assign({ success: true, found: true }, receipt);
}
function p5VerifyFile(receipt, p) {
  const file = DriveApp.getFileById(receipt.fileId);
  if (file.isTrashed() || file.getSize() !== receipt.fileSize || file.getMimeType() !== receipt.mimeType
      || file.getSharingAccess() !== DriveApp.Access.ANYONE_WITH_LINK) p5Fail('not_public_media');
  const parents = file.getParents(); let valid = false;
  while (parents.hasNext()) if (parents.next().getId() === receipt.folderId) valid = true;
  if (!valid) p5Fail('folder_mismatch');
  p5Site(receipt.site);
  if (p5Target(receipt, p, false).getId() !== receipt.folderId) p5Fail('folder_mismatch');
  return file;
}
function p5Read(r, p) {
  if (typeof r.assetId !== 'string' || !/^m_[a-f0-9]{64}$/.test(r.assetId)) p5Fail('invalid_asset_id');
  const receipt = p5Database('sites/' + r.site + '/mediaReceipts/' + r.assetId, null, null);
  if (!receipt || receipt.site !== r.site || receipt.public !== true) p5Fail('not_public_media');
  if (receipt.storage === 'hosting') return p5ReadHostedImage(receipt);
  let file = p5VerifyFile(receipt, p);
  if (r.thumbnail === true && receipt.thumbnailFileId) {
    file = DriveApp.getFileById(receipt.thumbnailFileId);
    if (file.isTrashed() || file.getMimeType() !== 'image/png' || file.getSize() > P5_THUMB_LIMIT
        || file.getSharingAccess() !== DriveApp.Access.ANYONE_WITH_LINK) p5Fail('not_public_media');
    const parents = file.getParents(); let valid = false;
    while (parents.hasNext()) if (parents.next().getId() === receipt.folderId) valid = true;
    let marker; try { marker = JSON.parse(file.getDescription()); } catch (_) { p5Fail('not_public_media'); }
    if (!valid || marker.assetId !== receipt.assetId || marker.thumbnail !== true || marker.site !== r.site) p5Fail('not_public_media');
  }
  if (file.getSize() > P5_LIMIT) p5Fail('file_too_large');
  return { success: true, fileId: file.getId(), mimeType: file.getMimeType(),
    fileSize: file.getSize(), fileData: Utilities.base64Encode(file.getBlob().getBytes()) };
}

// Existing imported covers are already public Hosting files. Their server
// receipt, rather than a caller-supplied URL, selects the immutable image.
function p5ReadHostedImage(receipt) {
  if (receipt.site !== 'yogen' || receipt.kind !== 'Images'
      || !['image/png', 'image/jpeg', 'image/webp'].includes(receipt.mimeType)
      || !/^[a-f0-9]{64}$/.test(receipt.sha256 || '')
      || !Number.isInteger(receipt.fileSize) || receipt.fileSize <= 0 || receipt.fileSize > P5_LIMIT) p5Fail('not_public_media');
  const match = /^https:\/\/portfolio-14d15\.web\.app\/project-media\/([a-f0-9]{64})\.(jpg|jpeg|png|webp)$/.exec(receipt.publicUrl || '');
  if (!match || match[1] !== receipt.sha256) p5Fail('not_public_media');
  const response = UrlFetchApp.fetch(receipt.publicUrl, { muteHttpExceptions: true, followRedirects: false });
  if (response.getResponseCode() !== 200) p5Fail('not_public_media');
  const bytes = response.getBlob().getBytes();
  if (bytes.length !== receipt.fileSize || !p5Signature(bytes, receipt.mimeType)
      || p5Hash(bytes) !== receipt.sha256) p5Fail('not_public_media');
  return { success: true, fileId: '', mimeType: receipt.mimeType,
    fileSize: bytes.length, fileData: Utilities.base64Encode(bytes) };
}
