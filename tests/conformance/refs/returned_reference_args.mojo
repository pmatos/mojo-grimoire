def first(ref xs: List[Int]) -> ref [xs] List[Int]:
    return xs


def at(ref xs: Array[Int, 2]) -> ref [xs] Int:
    return xs[0]


def count(xs: List[Int]) -> Int:
    return len(xs)


def count_ref(ref xs: List[Int]) -> Int:
    return len(xs)


def push(mut xs: List[Int]) -> Int:
    xs.append(9)
    return len(xs)


def two(a: List[Int], b: Int) -> Int:
    return len(a) + b


def both(a: List[Int], b: List[Int]) -> Int:
    return len(a) + len(b)


def keep(a: Int, mut b: Array[Int, 2]) -> Int:
    b[0] = 100
    return a


def main():
    var xs: List[Int] = [1, 2]
    print(count(first(xs)))
    print(count_ref(first(xs)))
    print(push(first(xs)))
    print(len(xs))
    print(two(first(xs), push(xs)))
    print(both(first(xs), first(xs)))
    var ys: Array[Int, 2] = [1, 2]
    print(keep(at(ys), ys))
    print(ys[0])
