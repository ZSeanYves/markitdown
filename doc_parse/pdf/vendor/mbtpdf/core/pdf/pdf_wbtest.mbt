///|
test "check_object_contains_renumbering detects indirects" {
  let changes : Map[Int, Int] = Map::new()
  changes.set(2, 99)
  assert_true(!check_object_contains_renumbering(changes, Integer(1)))
  assert_true(check_object_contains_renumbering(changes, Indirect(2)))
  let arr = Array([Integer(1), Indirect(2)])
  assert_true(check_object_contains_renumbering(changes, arr))
  let dict = Dictionary([("/A", Integer(1)), ("/B", Indirect(2))])
  assert_true(check_object_contains_renumbering(changes, dict))
  let stream_dict = Dictionary([("/Length", Integer(0)), ("/B", Indirect(2))])
  let stream = Stream(Ref::new((stream_dict, Stream::Got([]))))
  assert_true(check_object_contains_renumbering(changes, stream))
}
