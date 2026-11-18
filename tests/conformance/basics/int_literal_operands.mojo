def main():
    var x = 1
    var xs: List[Int] = [5, 6]
    var arr: Array[Int, 2] = [5, 6]
    print(x + [2], x - [1], x * [3], x // [2], x % [2])
    print(x == [1], x != [1], x < [2], x <= [0], x > [0], x >= [2])
    print([2] + x, [2] - x, [3] * x, [7] // x, [7] % x)
    print(1 + [2], [5] - 2, len(xs) + [1])
    x += [3]
    print(x, xs[[1]], arr[[0]])
