// Scrollkeeper by generalwrex. Created 2026-11-15.
// Read the LICENSE file before using any of this code.
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
// Extra addons to load after Scrollkeeper (folders with a .toc), from SK_EXTRA_ADDONS.
for (const extra of (process.env.SK_EXTRA_ADDONS || '').split(path.delimiter).filter(Boolean)) {
  const tocFile = fs.readdirSync(extra).find(f => f.endsWith('.toc'));
  if (!tocFile) continue;
  run("StaticPopupDialogs = StaticPopupDialogs or {}; SlashCmdList = SlashCmdList or {}; " +
      "DEFAULT_CHAT_FRAME = DEFAULT_CHAT_FRAME or { AddMessage = function(_, t) print(t) end }; " +
      "hooksecurefunc = hooksecurefunc or function(t, k, f) local o = t[k]; t[k] = function(...) local r = { o(...) }; f(...); return table.unpack(r) end end", 'extraprelude.lua');
  const extraToc = fs.readFileSync(path.join(extra, tocFile), 'utf8').split(/\r?\n/).filter(l => l.trim() && !l.startsWith('#'));
  for (const f of extraToc.filter(f => f.endsWith('.lua'))) run(fs.readFileSync(path.join(extra, f.replace(/\\/g, '/')), 'utf8'), path.basename(extra) + ':' + f, true);
}
run(fs.readFileSync(path.join(__dirname, 'scenario.lua'), 'utf8'), 'scenario.lua');
