def pick(ref a: List[Int], ref b: List[Int], first: Bool) -> ref[a, b] List[Int]:
    if first:
        return a
    return b


def eat(var r: List[Int]) -> Int:
    return len(r)


def main():
    var b: List[Int] = [3]
    print(pick([1], b, False), eat(b^))
