// Project-owner recovery only. Firebase CLI owns OAuth; passwords use stdin.
const fs = require('node:fs'), path = require('node:path'), os = require('node:os'), crypto = require('node:crypto');
const root = path.resolve(__dirname, '..');
const cliRoot = process.env.YOGEN_FIREBASE_TOOLS_ROOT || path.join(os.homedir(), 'AppData/Roaming/npm/node_modules/firebase-tools');
const {Command} = require(path.join(cliRoot, 'lib/command.js'));
const {requireAuth} = require(path.join(cliRoot, 'lib/requireAuth.js'));
const {Client} = require(path.join(cliRoot, 'lib/apiv2.js'));
async function input() { let value = ''; for await (const part of process.stdin) value += part; return JSON.parse(value); }
const command = new Command('yogen:owner-access').before(requireAuth).action(async options => {
  const value = await input();
  const login = String(value.login || 'admin@gmail.com').trim().toLowerCase();
  if (!/^[a-z0-9][a-z0-9@._+-]{2,199}$/.test(login) || typeof value.password !== 'string' || value.password.length < 12 || value.password.length > 128) throw Error('Invalid input');
  const email = crypto.createHash('sha256').update(login).digest('hex') + '@login.yogen.invalid';
  const api = new Client({urlPrefix: 'https://identitytoolkit.googleapis.com', apiVersion: 'v1'});
  const safeLog = {skipLog: {body: true, resBody: true}};
  const lookup = await api.post(`/projects/${options.project}/accounts:lookup`, {email: [email]}, safeLog);
  const user = lookup.body.users?.[0];
  if (!user || user.email !== email) throw Error('Account missing');
  const identity = JSON.parse(fs.readFileSync(path.join(root, 'config/identity.phase04.json'), 'utf8'));
  if (login === identity.managerLogin && user.localId !== identity.managerUid) throw Error('Owner identity mismatch');
  await api.post(`/projects/${options.project}/accounts:update`, {localId: user.localId, password: value.password, validSince: String(Math.floor(Date.now() / 1000)), returnSecureToken: false}, safeLog);
  value.password = '';
  if (login === identity.managerLogin) {
    fs.rmSync(path.join(root, '.runtime/yogen-owner.local.json'), {force: true});
    fs.writeFileSync(path.join(root, '.runtime/owner-access-activated.json'), JSON.stringify({uid: user.localId, passwordChosenLocally: true, date: new Date().toISOString()}));
  }
  console.log(JSON.stringify({passwordUpdated: true, uidPreserved: true, noEmailSent: true, roleUnchanged: true}));
});
command.runner()({project: 'portfolio-14d15', config: 'firebase.phase04.json', nonInteractive: true}).catch(() => {
  console.error('Access update failed. Check project-owner Firebase CLI login and account username. No password printed.'); process.exitCode = 1;
});
