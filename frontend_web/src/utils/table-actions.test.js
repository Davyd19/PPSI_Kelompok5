import {test} from 'node:test';import assert from 'node:assert/strict';import {actionAppearance} from './table-actions.js';
test('row action icons preserve destructive and ordinary meanings',()=>{
 for(const [label,icon] of [['Lihat detail','eye'],['Ubah','edit'],['Hapus','trash'],['Akhiri','close'],['Ganti','refresh'],['Reset sandi','key'],['Unggah bukti','upload'],['Tinjau','shield']])assert.equal(actionAppearance(label).icon,icon,label);
 assert.equal(actionAppearance('Nonaktifkan').tone,'danger');assert.equal(actionAppearance('Aktifkan').tone,'success');
});
