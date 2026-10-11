import fs from 'node:fs';
import path from 'node:path';
import { initializeTestEnvironment, assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc, updateDoc, serverTimestamp, collection, getDocs, writeBatch, setLogLevel } from 'firebase/firestore';
setLogLevel('silent');
const root = path.resolve(import.meta.dirname, '../..');
const report = { environment: 'Real rules emulator, demo-yogen-phase05; server receipts seeded with rules disabled', checks: [], errors: [] };
let env;
const site = 'phase04-test', base = `sites/${site}`;
const stamp = actor => ({ createdAt: serverTimestamp(), createdBy: actor, updatedAt: serverTimestamp(), updatedBy: actor });
const text = { ar: 'صورة اختبار', en: 'Test image' };
const id = 'm_' + 'a'.repeat(64);
const receipt = { assetId: id, site, fileId: 'drive-file-123456', fileName: 'صورة.png', mimeType: 'image/png',
  fileSize: 100, folderId: 'drive-folder-1234', projectId: 'project-a', scope: 'project', kind: 'Images',
  uploadedBy: 'editor', requestId: 'request-0001', sha256: 'b'.repeat(64), thumbnailFileId: 'thumbnail-file-1234',
  viewUrl: 'https://drive.google.com/file/d/drive-file-123456/view', downloadUrl: 'https://drive.google.com/uc?export=download&id=drive-file-123456', public: true };
const media = actor => ({ public: { id, driveFileId: receipt.fileId, name: receipt.fileName, mime: receipt.mimeType,
  bytes: receipt.fileSize, alt: text, thumbnailDriveFileId: receipt.thumbnailFileId },
  source: { folderId: receipt.folderId, originProjectId: receipt.projectId, scope: receipt.scope,
    requestId: receipt.requestId, sha256: receipt.sha256, uploadedBy: receipt.uploadedBy,
    viewUrl: receipt.viewUrl, downloadUrl: receipt.downloadUrl }, ready: true, verified: true, ...stamp(actor) });
const operation = actor => ({ requestId: 'request-0001', projectId: 'project-a', scope: 'project', kind: 'Images',
  fileName: 'صورة.png', mimeType: 'image/png', fileSize: 100, sha256: 'b'.repeat(64), alt: text, state: 'uploading', ...stamp(actor) });
async function check(name, fn) { await fn(); report.checks.push({ name, ok: true }); }
try {
  env = await initializeTestEnvironment({ projectId: 'demo-yogen-phase05', firestore: {
    host: '127.0.0.1', port: 8085, rules: fs.readFileSync(path.join(root, 'firebase/firestore.phase05.rules'), 'utf8') } });
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async context => {
    const db = context.firestore();
    for (const [uid, role] of [['manager','manager'],['editor','editor'],['disabled','editor']]) {
      await setDoc(doc(db, `${base}/adminUsers/${uid}`), { role, enabled: uid !== 'disabled', loginName: uid, ...stamp('manager') });
    }
  });
  const manager = env.authenticatedContext('manager').firestore(), editor = env.authenticatedContext('editor').firestore();
  const visitor = env.unauthenticatedContext().firestore(), roleless = env.authenticatedContext('roleless').firestore();
  await check('P05-T01 manager settings and routing; editor change denied', async () => {
    await assertSucceeds(setDoc(doc(manager, `${base}/settings/drive`), { rootFolderId: 'test' }));
    await assertSucceeds(setDoc(doc(manager, `${base}/mediaRouting/current`), { endpoint: 'https://script.google.com/macros/s/test-deployment/exec', version: 5, updatedAt: serverTimestamp(), updatedBy: 'manager' }));
    await assertFails(setDoc(doc(editor, `${base}/settings/drive`), { rootFolderId: 'forged' }));
    await assertFails(setDoc(doc(editor, `${base}/mediaRouting/current`), { endpoint: 'https://example.com', version: 5, updatedAt: serverTimestamp(), updatedBy: 'editor' }));
    await assertSucceeds(getDoc(doc(visitor, `${base}/mediaRouting/current`)));
    await assertFails(getDoc(doc(visitor, `${base}/settings/drive`)));
  });
  await check('Client cannot create trusted receipt, even manager', async () => {
    await assertFails(setDoc(doc(manager, `${base}/mediaReceipts/${id}`), receipt));
    await assertFails(setDoc(doc(editor, `${base}/mediaReceipts/${id}`), receipt));
  });
  await check('Forged ready reference without a receipt rejected', async () => {
    await assertFails(setDoc(doc(editor, `${base}/media/${id}`), media('editor')));
  });
  await env.withSecurityRulesDisabled(c => setDoc(doc(c.firestore(), `${base}/mediaReceipts/${id}`), receipt));
  await check('Attested reference registration and staff library reads', async () => {
    await assertSucceeds(setDoc(doc(editor, `${base}/media/${id}`), media('editor')));
    await assertSucceeds(getDocs(collection(editor, `${base}/media`)));
    await assertFails(getDoc(doc(visitor, `${base}/media/${id}`)));
    await assertFails(getDoc(doc(roleless, `${base}/media/${id}`)));
    await assertFails(getDoc(doc(visitor, `${base}/mediaReceipts/${id}`)));
  });
  await check('Receipt binds Drive ID, thumbnail, MIME, size, folder, uploader and hash', async () => {
    const snapshot = (await getDoc(doc(editor, `${base}/media/${id}`))).data();
    for (const [field, value] of [['driveFileId','other-file-12345'],['thumbnailDriveFileId','other-thumb-1234'],['mime','video/mp4'],['bytes',101],['name','forged.png']]) {
      await assertFails(updateDoc(doc(editor, `${base}/media/${id}`), { public: { ...snapshot.public, [field]: value }, updatedAt: serverTimestamp(), updatedBy: 'editor' }));
    }
    for (const field of ['folderId','uploadedBy','sha256']) {
      await assertFails(updateDoc(doc(editor, `${base}/media/${id}`), { source: { ...snapshot.source, [field]: 'forged' }, updatedAt: serverTimestamp(), updatedBy: 'editor' }));
    }
  });
  await check('Descriptions editable; storage metadata and original audit preserved', async () => {
    await assertSucceeds(updateDoc(doc(editor, `${base}/media/${id}`), { 'public.alt': { ar: 'وصف جديد', en: 'New description' }, updatedAt: serverTimestamp(), updatedBy: 'editor' }));
    await assertFails(updateDoc(doc(editor, `${base}/media/${id}`), { createdBy: 'manager', updatedAt: serverTimestamp(), updatedBy: 'editor' }));
  });
  await check('Oversize and embedded file data are refused in persisted operations', async () => {
    await assertFails(setDoc(doc(editor, `${base}/mediaOperations/too-big`), { ...operation('editor'), fileSize: 5242881 }));
    await assertFails(setDoc(doc(editor, `${base}/mediaOperations/encoded`), { ...operation('editor'), fileData: 'base64' }));
  });
  await check('Pending requests persist with immutable input; another member cannot edit', async () => {
    await assertSucceeds(setDoc(doc(editor, `${base}/mediaOperations/${id}`), operation('editor')));
    await assertSucceeds(updateDoc(doc(editor, `${base}/mediaOperations/${id}`), { state: 'uncertain', updatedAt: serverTimestamp(), updatedBy: 'editor' }));
    await assertFails(updateDoc(doc(editor, `${base}/mediaOperations/${id}`), { projectId: 'renamed', updatedAt: serverTimestamp(), updatedBy: 'editor' }));
    await assertFails(updateDoc(doc(manager, `${base}/mediaOperations/${id}`), { state: 'registered', updatedAt: serverTimestamp(), updatedBy: 'manager' }));
  });
  await check('Revoked, roleless and anonymous cannot register or prepare uploads', async () => {
    for (const db of [visitor, roleless, env.authenticatedContext('disabled').firestore()]) {
      await assertFails(setDoc(doc(db, `${base}/mediaOperations/unauthorized`), operation('disabled')));
    }
  });
  await check('Six verified media publish atomically within rule read budget; forged snapshot rejected', async () => {
    const assets = Array.from({ length: 6 }, (_, i) => ({ ...media('editor').public, id: 'budget-' + i }));
    await env.withSecurityRulesDisabled(async c => {
      for (const asset of assets) await setDoc(doc(c.firestore(), `${base}/media/${asset.id}`), { public: asset, ready: true, verified: true });
      await setDoc(doc(c.firestore(), `${base}/categories/media-tests`), { name: text, enabled: true, order: 0 });
    });
    const content = slug => ({ title: text, summary: text, body: text, contribution: text,
      categoryId: 'media-tests', slug, usage: 'demo', attribution: 'company', mediaIds: assets.map(v => v.id), links: [], order: 0, year: null });
    async function publish(project, forged) {
      const c = content(project), draft = { content: c, status: 'draft', revision: 1, publishedRevision: 0, stableSlug: '', internalNote: '', ...stamp('editor') };
      await setDoc(doc(editor, `${base}/projectDrafts/${project}`), draft);
      const stored = (await getDoc(doc(editor, `${base}/projectDrafts/${project}`))).data();
      const batch = writeBatch(editor);
      batch.set(doc(editor, `${base}/projectDrafts/${project}`), { ...stored, status: 'published', revision: 2,
        publishedRevision: 2, stableSlug: project, updatedAt: serverTimestamp(), updatedBy: 'editor' });
      batch.set(doc(editor, `${base}/projects/${project}`), { projectId: project, content: c, category: text,
        assets: forged ? assets.map((v,i) => i === 5 ? { ...v, driveFileId: 'forged-file-1234' } : v) : assets,
        revision: 2, publishedAt: serverTimestamp() });
      batch.set(doc(editor, `${base}/projectSlugs/${project}`), { projectId: project, revision: 2 });
      return batch.commit();
    }
    await assertSucceeds(publish('budget-six', false));
    await assertSucceeds(getDoc(doc(visitor, `${base}/projects/budget-six`)));
    await assertFails(publish('forged-six', true));
    if ((await getDoc(doc(visitor, `${base}/projects/forged-six`))).exists()) throw Error('partial_publication');
  });
} catch (e) { report.errors.push(e.message); process.exitCode = 1; }
finally { if (env) await env.cleanup(); fs.writeFileSync(path.join(root, 'phases/results/05/checks/rules-emulator.json'), JSON.stringify(report, null, 2));
  console.log(JSON.stringify({ checks: report.checks.length, errors: report.errors.length })); }
