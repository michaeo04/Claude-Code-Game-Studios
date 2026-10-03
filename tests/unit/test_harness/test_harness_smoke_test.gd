## Smoke test of the test harness itself (ADR-0009, spike T-1 / story TH-003).
## It proves that GUT discovers `*_test.gd` files, that framework-free support code loads through
## `preload` (no class cache needed), and that a test can run under the headless driver.
extends GutTest

const ClockStub = preload("res://tests/support/clock_stub.gd")


func test_clock_stub_starts_at_given_microseconds() -> void:
	var clock := ClockStub.new(1_500_000)
	assert_eq(clock.as_callable().call(), 1_500_000)


func test_clock_stub_advance_s_rounds_to_microseconds() -> void:
	var clock := ClockStub.new()
	clock.advance_s(0.016)
	assert_eq(clock.now_us, 16_000)
	clock.advance_us(4)
	assert_eq(clock.get_now_us(), 16_004)


func test_node_test_runs_headless_with_autofree() -> void:
	var node := Node.new()
	add_child_autofree(node)
	await get_tree().process_frame
	assert_true(node.is_inside_tree())
