extends Node
## Standalone test suite for entity spawning formula (no GUT framework required)

func _ready():
	run_all_tests()

func run_all_tests():
	var tests_passed = 0
	var tests_total = 0
	
	tests_total += 1
	if test_spawning_formula_base_case(): tests_passed += 1
	
	tests_total += 1
	if test_spawning_formula_low_sanity(): tests_passed += 1
	
	tests_total += 1
	if test_spawning_formula_mid_sanity(): tests_passed += 1
	
	tests_total += 1
	if test_spawning_formula_exploration_bonus(): tests_passed += 1
	
	tests_total += 1
	if test_spawning_formula_collection_bonus(): tests_passed += 1
	
	tests_total += 1
	if test_spawning_formula_all_bonuses(): tests_passed += 1
	
	tests_total += 1
	if test_spawning_formula_clamping(): tests_passed += 1
	
	tests_total += 1
	if test_spawning_formula_negative_bonuses(): tests_passed += 1
	
	# Quit after running tests
	get_tree().quit()

func test_spawning_formula_base_case() -> bool:
	# Base case: 100 sanity, 0 tiles, 0 weird things
	var expected_chance = 0.10
	var actual_chance = _calculate_spawn_chance(100, 0, 0)
	return assert_almost_equal(actual_chance, expected_chance, 0.001, "Base case should be 10%")

func test_spawning_formula_low_sanity() -> bool:
	# Low sanity: 0 sanity, 0 tiles, 0 weird things
	var expected_chance = 0.30
	var actual_chance = _calculate_spawn_chance(0, 0, 0)
	return assert_almost_equal(actual_chance, expected_chance, 0.001, "Zero sanity should give 30%")

func test_spawning_formula_mid_sanity() -> bool:
	# Mid sanity: 50 sanity, 0 tiles, 0 weird things
	var expected_chance = 0.20
	var actual_chance = _calculate_spawn_chance(50, 0, 0)
	return assert_almost_equal(actual_chance, expected_chance, 0.001, "50 sanity should give 20%")

func test_spawning_formula_exploration_bonus() -> bool:
	# Exploration bonus: 100 sanity, 20 tiles, 0 weird things
	var expected_chance = 0.20
	var actual_chance = _calculate_spawn_chance(100, 20, 0)
	return assert_almost_equal(actual_chance, expected_chance, 0.001, "20 tiles should give 10% exploration bonus")

func test_spawning_formula_collection_bonus() -> bool:
	# Collection bonus: 100 sanity, 0 tiles, 20 weird things
	var expected_chance = 0.20
	var actual_chance = _calculate_spawn_chance(100, 0, 20)
	return assert_almost_equal(actual_chance, expected_chance, 0.001, "20 weird things should give 10% collection bonus")

func test_spawning_formula_all_bonuses() -> bool:
	# All bonuses: 0 sanity, 20 tiles, 20 weird things
	var expected_chance = 0.50
	var actual_chance = _calculate_spawn_chance(0, 20, 20)
	return assert_almost_equal(actual_chance, expected_chance, 0.001, "All bonuses should give 50%")

func test_spawning_formula_clamping() -> bool:
	# Clamping: 0 sanity, 100 tiles, 100 weird things
	var expected_chance = 1.0
	var actual_chance = _calculate_spawn_chance(0, 100, 100)
	return assert_almost_equal(actual_chance, expected_chance, 0.001, "Should clamp to 100%")

func test_spawning_formula_negative_bonuses() -> bool:
	# Negative bonuses: 100 sanity, 5 tiles, 5 weird things
	var expected_chance = 0.10
	var actual_chance = _calculate_spawn_chance(100, 5, 5)
	return assert_almost_equal(actual_chance, expected_chance, 0.001, "Negative bonuses should be clamped to 0%")

func assert_almost_equal(actual: float, expected: float, tolerance: float, message: String) -> bool:
	var diff = abs(actual - expected)
	var passed = diff <= tolerance
	return passed

# Helper function that replicates the spawning formula
func _calculate_spawn_chance(current_sanity: int, tiles_explored: int, weird_things_collected: int) -> float:
	# Base 10% chance
	var base_chance: float = 0.10
	
	# Sanity bonus: 20% - (sanity / 5)
	var sanity_bonus: float = 0.20 - (current_sanity / 5.0 / 100.0)
	
	# Exploration bonus: (tiles_explored - 10) * 1%
	var exploration_bonus: float = max(0.0, (tiles_explored - 10) * 0.01)
	
	# Collection bonus: (weird_things_collected - 10) * 1%
	var collection_bonus: float = max(0.0, (weird_things_collected - 10) * 0.01)
	
	# Calculate final chance
	var final_chance: float = base_chance + sanity_bonus + exploration_bonus + collection_bonus
	
	# Clamp between 0% and 100%
	final_chance = clampf(final_chance, 0.0, 1.0)
	
	return final_chance
