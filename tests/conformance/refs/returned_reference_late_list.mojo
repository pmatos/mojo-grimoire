def pick(ref a: Int, ref b: Int, first: Bool) -> ref[a, b] Int:
    if first:
        return a
    return b


def pick_list(ref a: List[Int], ref b: List[Int], first: Bool) -> ref[a, b] List[Int]:
    if first:
        return a
    return b


def bump(mut x: Int) -> Int:
    x += 10
    return 0


def main():
    var a = 1
    var b = 2
    var l: List[Int] = [pick(a, b, True), bump(a)]
    print(l)
    var arr: Array[Int, 2] = [pick(a, b, True), bump(a)]
    print(arr)
    var xs: List[Int] = [1, 2]
    var ys: List[Int] = [3]
    print(pick_list(xs, ys, True), xs.pop())
    print(pick_list(xs, ys, True), len(xs))
