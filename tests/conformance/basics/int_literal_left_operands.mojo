def bump(mut x: Int) -> Int:
    x += 10
    return 5


def main():
    var x = 3
    print([2] < x, [2] <= x, [2] > x, [2] >= x, [2] == x, [2] != x)
    print([2] < 3, [[2]] == x, [x * 2] >= x, [x] != x)
    var a = 1
    print([a] < bump(a), a)
    var b = 1
    print([b] == bump(b) + 6, b)
