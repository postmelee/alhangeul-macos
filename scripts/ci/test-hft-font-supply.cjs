const {test} = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const {run,summarize,validateResult} = require('./hft-font-supply-adapter.cjs');
const check = (stage,status) => ({stage,status,reason:'testEvidence',evidenceKind:'synthetic'});
const report = checks => {
  const cases=[{checks}];
  return {schemaVersion:1,cases,summary:summarize(cases)};
};
test('공급 성공·렌더 미실행은 전체 완료가 아니다',()=>{
  const r=report([check('bytes','PASS'),check('render','NOT_RUN')]);
  validateResult(r);
  assert.equal(r.summary.complete,false);
  assert.equal(r.summary.supplyComplete,true);
});
test('대상 부재와 공급 실패는 공급 완료로 집계하지 않는다',()=>{
  for(const status of ['NOT_RUN','FAIL']) {
    const r=report([check('candidate',status),check('render','NOT_RUN')]);
    validateResult(r); assert.equal(r.summary.supplyComplete,false);
  }
});
test('허위 통과 요약·알 수 없는 판정·증거 없는 검사는 거부한다',()=>{
  const r=report([check('bytes','FAIL')]);r.summary.FAIL=0;
  assert.throws(()=>validateResult(r),/invalidSummary/);
  assert.throws(()=>summarize([{checks:[check('bytes','SKIP')]}]),/invalidStatus/);
  assert.throws(()=>validateResult({schemaVersion:1,cases:[{checks:[]}]}),/missingChecks/);
  const missing=report([check('bytes','PASS')]);delete missing.cases[0].checks[0].reason;
  assert.throws(()=>validateResult(missing),/missingEvidence/);
  const stage=report([check('unknown','PASS')]);
  assert.throws(()=>validateResult(stage),/invalidStage/);
  const evidence=report([check('bytes','PASS')]);evidence.cases[0].checks[0].evidenceKind='assumed';
  assert.throws(()=>validateResult(evidence),/invalidEvidence/);
});
test('중첩 결과의 원본 경로·bookmark·bytes는 거부한다',()=>{
  for(const key of ['sourceURL','bookmark','data','bytes','path']) {
    const r=report([check('bytes','PASS')]);r.cases[0].observations={reads:[{[key]:'private'}]};
    assert.throws(()=>validateResult(r),/privateField/);
  }
});
test('Swift 서버 시작 실패는 완료 결과로 바꾸지 않고 종료한다',async()=>{
  await assert.rejects(run({root:path.resolve(__dirname,'../..'),
    executable:path.join(__dirname,'missing-hft-probe','executable'),state:'unused',mode:'fixtures'}),/transportExited/);
  await assert.rejects(run({root:path.resolve(__dirname,'../..'),
    executable:path.join(__filename,'missing-executable'),state:'unused',mode:'fixtures'}),{code:'ENOTDIR'});
});
