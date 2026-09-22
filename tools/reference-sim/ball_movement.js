#!/usr/bin/env node
'use strict';
/**
 * Reference simulation for design/gdd/ball-movement.md's Formulas section
 * (F1 angular tracking, F2 forward speed/distance, F3 rate mode, F5a
 * dodge-time/T_DODGE_180, F5c resolution). This is the "Node reference
 * simulation" the GDD cites throughout as the source of its "exact to the
 * digits shown" oracle values.
 *
 * Checked in 2026-09-22 as part of the GDD's 3rd /design-review pass, after
 * the pass found the GDD cited this script ~12 times as an oracle authority
 * while it did not exist anywhere in the repo. Every assertion below was run
 * and passed before being written into the GDD text; see
 * design/gdd/reviews/ball-movement-review-log.md for the pass that required it.
 *
 * Uses STEER_ARC = PI (the reverted default per that pass — see Open
 * Question 7 and B8 in the GDD). Where a value is cited elsewhere in the GDD
 * at STEER_ARC = 3.0 rad (the B3-era default, now historical), it is noted
 * inline but not asserted as current.
 *
 * Run: node ball_movement.js
 * Exit code 0 = every assertion matched; non-zero = a mismatch was printed.
 */

const TWO_PI = 2 * Math.PI;

function wrap_angle(x) {
  return x - TWO_PI * Math.floor((x + Math.PI) / TWO_PI);
}

// ---- F1: angular tracking step (position mode), driven by a raw error `e` ---
// (F1's own worked-example table is stated directly in terms of e, not steer;
// the full e = wrap_angle(phi_anchor + STEER_ARC*steer - phi) composition is
// exercised separately below for the scripted scenarios.)
function f1_from_e(e, dt, tau, OMEGA_MAX) {
  const alpha = tau < 1e-4 ? 1 : 1 - Math.exp(-dt / tau);
  let step = e * alpha;
  const cap = OMEGA_MAX * dt;
  step = Math.max(-cap, Math.min(cap, step));
  return { alpha, step };
}

// One full scripted step, including the anchor/target composition and the
// snap rule (Core Rule 13 / F1): if the remaining wrapped error after this
// step is below 1e-6 rad, phi snaps exactly onto the target (mod 2*PI).
function f1_step(phi, phi_anchor, steer, dt, STEER_ARC, tau, OMEGA_MAX) {
  const s = Math.max(-1, Math.min(1, steer));
  const target = phi_anchor + STEER_ARC * s;
  const e = wrap_angle(target - phi);
  const r = f1_from_e(e, dt, tau, OMEGA_MAX);
  let phi_new = phi + r.step;
  const snapped = Math.abs(e - r.step) < 1e-6;
  if (snapped) phi_new = target;
  return { phi_new, e, alpha: r.alpha, step: r.step, snapped, target };
}

// ---- F2: forward speed and distance -----------------------------------------
function f2_speed(t, V_START, V_MAX, T_RAMP) {
  if (T_RAMP <= 0) return V_MAX;
  return V_START + (V_MAX - V_START) * Math.min(t / T_RAMP, 1);
}
function f2_S(t, V_START, V_MAX, T_RAMP) {
  if (T_RAMP <= 0) return V_MAX * t;
  if (t <= T_RAMP) return V_START * t + (V_MAX - V_START) * t * t / (2 * T_RAMP);
  return T_RAMP * (V_START + V_MAX) / 2 + V_MAX * (t - T_RAMP);
}

// ---- F3: rate mode (kept as a documented math reference for a possible
// future Game Modes/Alpha use — RATE is no longer wired to input_source
// FALLBACK for the MVP; see Rule 6 and Open Question 2) --------------------
function f3_step(w, steer, dt, OMEGA_MAX, tau) {
  const s = Math.max(-1, Math.min(1, steer));
  const w_ss = OMEGA_MAX * s;
  const alpha = tau < 1e-4 ? 1 : 1 - Math.exp(-dt / tau);
  const dphi = w_ss * dt + (w - w_ss) * tau * alpha;
  const w_new = w_ss + (w - w_ss) * (1 - alpha);
  return { w_new, dphi };
}

// ---- F5a: dodge time / T_DODGE_180 -------------------------------------------
function f5a_T(X, eps, OMEGA_MAX, tau) {
  if (X <= eps) return 0;
  const K = OMEGA_MAX * tau;
  if (eps < K) return (X - K) / OMEGA_MAX + tau * Math.log(K / eps);
  return (X - eps) / OMEGA_MAX;
}

// ---- Rule 13: BallConfig.validated()'s derived cross-knob check -------------
// Bisects BALL_LAG_TAU over [0, its clamped value] so that T(PI, 0.05) settles
// at T_DODGE_180_MAX, terminating at |T - T_DODGE_180_MAX| <= 1e-9 or after 60
// iterations. T(PI, 0.05, OMEGA_MAX, tau) is monotone non-decreasing in tau
// (flat while K <= eps, then strictly increasing), so bisection is well-posed
// whenever T(PI, 0.05, OMEGA_MAX, 0) <= T_DODGE_180_MAX (true for every
// OMEGA_MAX in the current safe range, 2.75-4.0 — see the corner sweep above;
// the worst case, OMEGA_MAX=2.75, gives 1.1242s, 0.016s of headroom under the
// 1.14s ceiling). If that ever stops holding (e.g. OMEGA_MAX's floor is tuned
// down further), this function will still run 60 iterations and return a
// tau near 0 without reaching the ceiling — it has no distinct signal for
// "unfixable by lowering BALL_LAG_TAU alone" (a documented open gap, see
// Recommended Revisions in the GDD's review log).
function bisect_ball_lag_tau(OMEGA_MAX, tau_clamped, T_DODGE_180_MAX) {
  let lo = 0, hi = tau_clamped;
  for (let i = 0; i < 60; i++) {
    const mid = (lo + hi) / 2;
    const t = f5a_T(Math.PI, 0.05, OMEGA_MAX, mid);
    if (Math.abs(t - T_DODGE_180_MAX) <= 1e-9) return mid;
    if (t > T_DODGE_180_MAX) hi = mid; else lo = mid;
  }
  return (lo + hi) / 2;
}

// ---- Fixture defaults (STEER_ARC = PI, reverted 2026-09-22) -----------------
const FIX = {
  STEER_ARC: Math.PI,
  BALL_LAG_TAU: 0.06,
  OMEGA_MAX: 3.0,
  V_START: 10,
  V_MAX: 25,
  T_RAMP: 90,
};

let failures = 0;
function check(label, actual, expected, tol) {
  tol = tol === undefined ? 1e-6 : tol;
  const ok = Math.abs(actual - expected) <= tol;
  if (!ok) {
    failures++;
    console.log(`FAIL ${label}: got ${actual}, expected ${expected} (tol ${tol})`);
  } else {
    console.log(`ok   ${label}: ${actual}`);
  }
}

console.log('=== F1 worked example (tau=0.06, OMEGA_MAX=3.0, dt=1/60) ===');
{
  const dt = 1 / 60, tau = 0.06;
  let r = f1_from_e(1.0, dt, tau, 3.0);
  check('F1 e=1.0 alpha', r.alpha, 0.242535, 1e-6);
  check('F1 e=1.0 step (uncapped 0.2425, capped to OMEGA_MAX*dt=0.05)', r.step, 0.05, 1e-6);
  r = f1_from_e(0.1, dt, tau, 3.0);
  check('F1 e=0.1 step', r.step, 0.0242535, 1e-6);
  r = f1_from_e(-1.0, dt, tau, 3.0);
  check('F1 e=-1.0 step', r.step, -0.05, 1e-6);
  r = f1_from_e(0.03, 1 / 60, 0, 3.0);
  check('F1 tau=0 e=0.03 (pure rate limit)', r.step, 0.03, 1e-6);
  r = f1_from_e(0.1, 1 / 60, 0, 3.0);
  check('F1 tau=0 e=0.1 (capped)', r.step, 0.05, 1e-6);
  r = f1_from_e(1, 1e-5, 9.99e-5, 3.0);
  check('F1 alpha guard (tau<1e-4)', r.alpha, 1, 0);
  r = f1_from_e(1, 1e-5, 1e-4, 3.0);
  check('F1 alpha guard (tau=1e-4)', r.alpha, 0.095163, 1e-6);
}

console.log('\n=== F1 0.1 rad target held 0.1s at 30/60/120 Hz (frame-rate independence) ===');
for (const hz of [30, 60, 120]) {
  const dt = 1 / hz;
  const n = Math.round(0.1 / dt);
  let phi = 0;
  for (let i = 0; i < n; i++) {
    const e = 0.1 - phi; // single target, |e|<=PI throughout: wrap is a no-op
    const r = f1_from_e(e, dt, 0.06, 3.0);
    phi += r.step;
  }
  check(`F1 phi after 0.1s @ ${hz}Hz`, phi, 0.0811124, 1e-6);
}

console.log('\n=== F1 frames to |e|<=0.05 from e=PI (AC-8 shape) ===');
for (const hz of [30, 60, 120]) {
  const dt = 1 / hz;
  let phi = 0, n = 0;
  while (Math.abs(Math.PI - phi) > 0.05) {
    const r = f1_from_e(Math.PI - phi, dt, 0.06, 3.0);
    phi += r.step;
    n++;
  }
  const expected = { 30: 32, 60: 64, 120: 128 }[hz];
  check(`F1 frames-to-tolerance @ ${hz}Hz`, n, expected, 0);
}

console.log('\n=== AC-10 (steer 0.5 held from reset, STEER_ARC=PI, phi_anchor=0) ===');
{
  const { STEER_ARC, BALL_LAG_TAU, OMEGA_MAX } = FIX;
  const dt = 1 / 60;
  let phi = 0, frame = 0, snapFrame = null;
  const r1 = f1_step(phi, 0, 0.5, dt, STEER_ARC, BALL_LAG_TAU, OMEGA_MAX);
  check('AC-10 frame 1 theta', r1.step, 0.05, 1e-6);
  phi = 0;
  for (let i = 1; i <= 200; i++) {
    const r = f1_step(phi, 0, 0.5, dt, STEER_ARC, BALL_LAG_TAU, OMEGA_MAX);
    phi = r.phi_new;
    if (r.snapped && snapFrame === null) snapFrame = i;
    if (snapFrame) break;
  }
  check('AC-10 snap frame', snapFrame, 72, 0);
  check('AC-10 phi at snap == PI/2', phi, Math.PI / 2, 1e-9);
}

console.log('\n=== AC-11 (steer 1 to snap at STEER_ARC=PI, then resume re-base) ===');
{
  const { STEER_ARC, BALL_LAG_TAU, OMEGA_MAX } = FIX;
  const dt = 1 / 60;
  let phi = 0, snapFrame = null;
  for (let i = 1; i <= 300; i++) {
    const r = f1_step(phi, 0, 1.0, dt, STEER_ARC, BALL_LAG_TAU, OMEGA_MAX);
    phi = r.phi_new;
    if (r.snapped && snapFrame === null) snapFrame = i;
    if (snapFrame) break;
  }
  check('AC-11 phi snaps to PI', phi, Math.PI, 1e-9);
  // on_resumed(): re-base armed; step(0, 0.3) is a no-op, doesn't consume it.
  // step(1/60, 0.5) is the first moving step after on_resumed -> re-base:
  const phi_anchor_rebased = phi - STEER_ARC * 0.5;
  check('AC-11 phi_anchor after re-base', phi_anchor_rebased, Math.PI / 2, 1e-9);
}

console.log('\n=== F2 speed/distance (V_START=10, V_MAX=25, T_RAMP=90) ===');
{
  const { V_START, V_MAX, T_RAMP } = FIX;
  check('F2 speed(0)', f2_speed(0, V_START, V_MAX, T_RAMP), 10, 1e-9);
  check('F2 speed(45)', f2_speed(45, V_START, V_MAX, T_RAMP), 17.5, 1e-9);
  check('F2 speed(90)', f2_speed(90, V_START, V_MAX, T_RAMP), 25, 1e-9);
  check('F2 speed(120) (past ramp)', f2_speed(120, V_START, V_MAX, T_RAMP), 25, 1e-9);
  check('F2 S(0)', f2_S(0, V_START, V_MAX, T_RAMP), 0, 1e-9);
  check('F2 S(45)', f2_S(45, V_START, V_MAX, T_RAMP), 618.75, 1e-6);
  check('F2 S(90)', f2_S(90, V_START, V_MAX, T_RAMP), 1575, 1e-6);
  check('F2 S(120)', f2_S(120, V_START, V_MAX, T_RAMP), 2325, 1e-6);
  check('F2 S(682.36) ~ S_PRECISION_LIMIT (16384)', f2_S(682.36, V_START, V_MAX, T_RAMP), 16384, 1);
  check('F2 sentinel speed(0), T_RAMP=0', f2_speed(0, V_START, V_MAX, 0), 25, 1e-9);
  check('F2 sentinel S(0), T_RAMP=0', f2_S(0, V_START, V_MAX, 0), 0, 1e-9);
  check('F2 sentinel S(10), T_RAMP=0', f2_S(10, V_START, V_MAX, 0), 250, 1e-9);
  check('F2 sentinel S(10), T_RAMP=-5', f2_S(10, V_START, V_MAX, -5), 250, 1e-9);
  if (!Number.isFinite(f2_S(0, V_START, V_MAX, 0))) { failures++; console.log('FAIL F2 sentinel produced non-finite'); }
}

console.log('\n=== F3 rate mode (documented reference only; not wired to MVP FALLBACK) ===');
{
  const dt = 1 / 60;
  let r = f3_step(0, 1, dt, 3.0, 0.06);
  check('F3 w after 1 frame', r.w_new, 0.727605, 1e-6);
  check('F3 dphi frame 1', r.dphi, 0.0063437, 1e-6);
  for (const hz of [30, 60, 120]) {
    const dth = 1 / hz;
    const n = Math.round(0.1 / dth);
    let w = 0, phi = 0;
    for (let i = 0; i < n; i++) { const rr = f3_step(w, 1, dth, 3.0, 0.06); phi += rr.dphi; w = rr.w_new; }
    check(`F3 phi after 0.1s @ ${hz}Hz`, phi, 0.153998, 1e-6);
  }
  {
    const dth = 1 / 6000;
    let w = 0;
    for (let t = 0; t < 1; t += dth) { const rr = f3_step(w, 1, dth, 3.0, 0.06); w = rr.w_new; }
    let coast = 0;
    for (let t = 0; t < 5; t += dth) { const rr = f3_step(w, 0, dth, 3.0, 0.06); w = rr.w_new; coast += rr.dphi; if (Math.abs(w) < 1e-6) break; }
    check('F3 coast distance after release', coast, 0.18, 1e-3);
  }
}

console.log('\n=== F5a T(X,eps): T_DODGE_180 (OMEGA_MAX=3.0, tau=0.06 -> K=0.18) ===');
{
  const { OMEGA_MAX, BALL_LAG_TAU } = FIX;
  check('F5a T(PI,0.05) = T_DODGE_180', f5a_T(Math.PI, 0.05, OMEGA_MAX, BALL_LAG_TAU), 1.064054, 1e-6);
  check('F5a T(PI/2, 0.1*PI/2)', f5a_T(Math.PI / 2, 0.1 * Math.PI / 2, OMEGA_MAX, BALL_LAG_TAU), 0.471771, 1e-6);
  const K = OMEGA_MAX * BALL_LAG_TAU;
  check('F5a K', K, 0.18, 1e-9);
  check('F5a boundary eps==K, both branches agree', f5a_T(Math.PI, K, OMEGA_MAX, BALL_LAG_TAU), 0.987198, 1e-6);
  check('F5a T(0,0.1) guard', f5a_T(0, 0.1, OMEGA_MAX, BALL_LAG_TAU), 0, 0);
  check('F5a T(0.1,0.1) guard (X==eps)', f5a_T(0.1, 0.1, OMEGA_MAX, BALL_LAG_TAU), 0, 0);
  check('F5a T(0.1+1e-6,0.1) just above guard', f5a_T(0.1 + 1e-6, 0.1, OMEGA_MAX, BALL_LAG_TAU), 0.008601, 1e-6);
  check('Reset glide worst case == T_DODGE_180 at STEER_ARC=PI (Rule 5)', f5a_T(FIX.STEER_ARC, 0.05, OMEGA_MAX, BALL_LAG_TAU), 1.064054, 1e-6);
}

console.log('\n=== F5a knob-interaction corners (safe ranges: OMEGA_MAX 2.75-4.0, tau 0-0.072) ===');
{
  const corners = [
    { OMEGA_MAX: 2.75, BALL_LAG_TAU: 0 },
    { OMEGA_MAX: 2.75, BALL_LAG_TAU: 0.072 },
    { OMEGA_MAX: 4.0, BALL_LAG_TAU: 0 },
    { OMEGA_MAX: 4.0, BALL_LAG_TAU: 0.072 },
  ];
  const T_DODGE_180_MAX = 1.14;
  for (const c of corners) {
    const t = f5a_T(Math.PI, 0.05, c.OMEGA_MAX, c.BALL_LAG_TAU);
    console.log(`  corner OMEGA_MAX=${c.OMEGA_MAX} tau=${c.BALL_LAG_TAU} -> T(PI,0.05)=${t.toFixed(4)}s  ${t <= T_DODGE_180_MAX ? 'SAFE' : 'UNSAFE'}`);
  }
  check('F5a corner (2.75, 0.072) (only unsafe corner)', f5a_T(Math.PI, 0.05, 2.75, 0.072), 1.169, 1e-3);
  check('F5a corner (2.75, 0) (safe)', f5a_T(Math.PI, 0.05, 2.75, 0), 1.1242, 1e-4);
  check('F5a corner (4.0, 0) (safe)', f5a_T(Math.PI, 0.05, 4.0, 0), 0.7729, 1e-4);
  check('F5a corner (4.0, 0.072) (safe)', f5a_T(Math.PI, 0.05, 4.0, 0.072), 0.8395, 1e-4);
}

console.log('\n=== AC-19b/AC-19c: Rule 13 bisection-corrected BALL_LAG_TAU ===');
{
  const T_DODGE_180_MAX = 1.14;
  const corrected = bisect_ball_lag_tau(2.75, 0.072, T_DODGE_180_MAX);
  check('AC-19b corrected BALL_LAG_TAU @ OMEGA_MAX=2.75, pre-clamp tau=0.072', corrected, 0.046964, 1e-6);
  check('AC-19b corrected value gives T(PI,0.05) == ceiling', f5a_T(Math.PI, 0.05, 2.75, corrected), T_DODGE_180_MAX, 1e-6);
  if (!(corrected < 0.072)) { failures++; console.log('FAIL AC-19b: corrected tau not strictly smaller than pre-correction'); }
  // AC-19c boundary-pair oracle: the tau at OMEGA_MAX=2.75 that lands exactly
  // on the ceiling, and the pair 1e-6 below/above it (no clamp / one clamp).
  const tauAtCeiling = bisect_ball_lag_tau(2.75, 1, T_DODGE_180_MAX);
  check('AC-19c tau @ OMEGA_MAX=2.75 landing exactly on T_DODGE_180_MAX', tauAtCeiling, 0.046964, 1e-6);
  const justBelow = f5a_T(Math.PI, 0.05, 2.75, tauAtCeiling - 1e-6);
  const justAbove = f5a_T(Math.PI, 0.05, 2.75, tauAtCeiling + 1e-6);
  console.log(`  T at tau-1e-6: ${justBelow.toFixed(9)} (expect <= ${T_DODGE_180_MAX}, no clamp)`);
  console.log(`  T at tau+1e-6: ${justAbove.toFixed(9)} (expect >  ${T_DODGE_180_MAX}, exactly one clamp)`);
  if (!(justBelow <= T_DODGE_180_MAX)) { failures++; console.log('FAIL AC-19c: just-below pair should not clamp'); }
  if (!(justAbove > T_DODGE_180_MAX)) { failures++; console.log('FAIL AC-19c: just-above pair should clamp'); }
}

console.log('\n=== F5c resolution (STEER_ARC=PI, DEAD_ZONE=1.5deg) ===');
{
  const STEER_ARC = Math.PI;
  function ball_deg_per_tilt_deg(TFS, DZ) { return STEER_ARC / ((TFS - DZ) * Math.PI / 180); }
  check('F5c TILT_FULL_SCALE=25', ball_deg_per_tilt_deg(25, 1.5), 7.66, 0.01);
  check('F5c TILT_FULL_SCALE=35', ball_deg_per_tilt_deg(35, 1.5), 5.37, 0.01);
}

console.log(`\n${failures === 0 ? 'ALL CHECKS PASSED' : failures + ' CHECK(S) FAILED'}`);
process.exit(failures === 0 ? 0 : 1);
