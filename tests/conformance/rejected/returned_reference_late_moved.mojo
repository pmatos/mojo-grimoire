def pick(ref a: List[Int], ref b: List[Int], first: Bool) -> ref[a, b] List[Int]:
    if first:
        return a
    return b


def eat(var r: List[Int]) -> Int:
    return len(r)


def main():
    var a: List[Int] = [1, 2]
    var b: List[Int] = [3]
    print(pick(a, b, True), eat(a^))
