def main():
    var xs: List[Int] = [1, 2]
    print(xs)
    var flags: List[Bool] = [True, False]
    print(flags)
    var nested: List[List[Int]] = [[1, 2], [3]]
    print(nested, nested[1])
    var e: List[Int] = []
    print(e)
    var none: List[List[Bool]] = [[]]
    print(none, "and", xs, len(xs))
