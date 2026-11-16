const fengari = require('fengari');
const { lua, lauxlib, lualib, to_luastring } = fengari;
const fs = require('fs'), path = require('path');
const root = process.argv[2];
const cls = process.argv[3] || 'MAGE';
const locale = process.argv[4] || 'enUS';
const L = lauxlib.luaL_newstate(); lualib.luaL_openlibs(L);
function run(code, name, nargs) {
  if (lauxlib.luaL_loadbuffer(L, to_luastring(code), null, to_luastring('@' + name)) !== 0) throw new Error(lua.lua_tojsstring(L, -1));
  let n = 0;
  if (nargs) { lua.lua_pushstring(L, to_luastring('Scrollkeeper')); lua.lua_getglobal(L, to_luastring('__NS')); n = 2; }
  if (lua.lua_pcall(L, n, 0, 0) !== 0) throw new Error(name + ': ' + lua.lua_tojsstring(L, -1));
}
run(`MOCK_CLASS = "${cls}"; MOCK_LOCALE = "${locale}"; __NS = {}`, 'pre');
run(fs.readFileSync(path.join(__dirname, 'mock.lua'), 'utf8'), 'mock.lua');
const toc = fs.readFileSync(path.join(root, 'Scrollkeeper.toc'), 'utf8').split(/\r?\n/).filter(l => l.trim() && !l.startsWith('#'));
for (const f of toc.filter(f => f.endsWith('.lua'))) run(fs.readFileSync(path.join(root, f.replace(/\\/g, '/')), 'utf8'), f, true);
run(fs.readFileSync(path.join(__dirname, 'scenario.lua'), 'utf8'), 'scenario.lua');
