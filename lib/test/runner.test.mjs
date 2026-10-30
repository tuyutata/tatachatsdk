// 验证发现与真实JSON事件的完整性，失败不得变成“测试通过”。
import {test} from 'node:test';
import assert from 'node:assert/strict';
import {mkdtempSync,mkdirSync,writeFileSync,rmSync} from 'node:fs';
import {join} from 'node:path';
import {tmpdir} from 'node:os';
import {discoverTests,verifyReport} from './run.mjs';

function report(file,extra={}){return [
 {type:'suite',suite:{id:1,path:file}},
 {type:'testStart',test:{id:1,suiteID:1,name:'case'}},
 {type:'testDone',testID:1,result:'success',skipped:false,...extra},
 {type:'done',success:true},
];}
const encode=rows=>rows.map(row=>JSON.stringify(row)).join('\n');
test('按包发现测试，忽略辅助文件并拒绝重复或空包',t=>{
 const work=mkdtempSync(join(tmpdir(),'tatachat-runner-'));t.after(()=>rmSync(work,{recursive:true,force:true}));
 mkdirSync(join(work,'test'));writeFileSync(join(work,'test/a_test.dart'),'void main() {}');writeFileSync(join(work,'test/helper.dart'),'');
 const pkg={name:'fixture',path:work};assert.equal(discoverTests([pkg])[0].files.length,1);assert.throws(()=>discoverTests([pkg,pkg]),/重复/);
 assert.throws(()=>discoverTests([{name:'empty',path:join(work,'absent')}]),/缺少/);
});
test('完整结束通过，跳过、失败、漏加载、漏结束、重复结束及畸形报告拒绝',()=>{
 const file='/fixture/a_test.dart',rows=report(file);assert.equal(verifyReport(encode(rows),[file],'/fixture').passed,1);
 for(const change of [{skipped:true},{result:'failure'}])assert.throws(()=>verifyReport(encode(report(file,change)),[file],'/fixture'));
 assert.throws(()=>verifyReport(encode(rows),[file,'/fixture/missing_test.dart'],'/fixture'));
 assert.throws(()=>verifyReport(encode(rows.filter(row=>row.type!=='testDone')),[file],'/fixture'));
 assert.throws(()=>verifyReport(encode([...rows,rows[2]]),[file],'/fixture'));
 assert.throws(()=>verifyReport(encode(rows.filter(row=>row.type!=='done')),[file],'/fixture'));
 assert.throws(()=>verifyReport('broken',[file],'/fixture'));
 const empty='/fixture/empty_test.dart';
 assert.throws(()=>verifyReport(encode([...rows,{type:'suite',suite:{id:2,path:empty}}]),[file,empty],'/fixture'),/实际用例/);
});

test('正式lib/test与临时工具布局按明确路径发现',t=>{
 const work=mkdtempSync(join(tmpdir(),'tatachat-lib-'));t.after(()=>rmSync(work,{recursive:true,force:true}));
 mkdirSync(join(work,'lib/test'),{recursive:true});mkdirSync(join(work,'test'));
 writeFileSync(join(work,'lib/test/a_test.dart'),'void main() {}');writeFileSync(join(work,'test/mapped_test.dart'),'void main() {}');
 const groups=discoverTests([{name:'tatachat_sdk',path:work}]);
 assert.deepEqual(groups[0].files,[join(work,'lib/test/a_test.dart')]);
 assert.deepEqual(discoverTests([{name:'tatachat_sdk',path:work,testPath:join(work,'test')}])[0].files,[join(work,'test/mapped_test.dart')]);
});
