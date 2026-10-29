import {test} from 'node:test';
import assert from 'node:assert/strict';
import {validateAccount} from '../src/utils/exampleAccounts.js';
test('all nine sample identities select role only on their platform',()=>{
 for(const [identity,role,platform] of [['admin','admin','web'],['kesiswaan','kesiswaan','web'],['kepsek','kepala_sekolah','web'],['siswa','siswa','mobile'],['ortu','orang_tua','mobile'],['guru','guru','mobile'],['wali','wali_kelas','mobile'],['bk','guru_bk','mobile'],['pembina','pembina_ekstrakurikuler','mobile']]){assert.equal(validateAccount(identity,'Contoh123!',platform).role,role);assert.ok(validateAccount(identity,'Contoh123!',platform==='web'?'mobile':'web').error);}
});
test('unknown identities and wrong passwords rejected locally',()=>{assert.ok(validateAccount('unknown','Contoh123!','web').error);assert.ok(validateAccount('admin','wrong','web').error);assert.equal(validateAccount(' ADMIN ','Contoh123!','web').role,'admin');});
