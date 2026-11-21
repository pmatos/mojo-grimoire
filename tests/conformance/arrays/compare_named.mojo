def main():
    var a = [1, 2]
    var b = [1, 3]
    print(a < b, a == b, a != b, a >= b, a <= b, a > b)
    print(a == a, a < a, a == [1, 2], [1, 2] < a)
    var c = [1]
    print(c == [1], [1] == c, c < [2], [0] < c)
    var n = [[1, 2], [3, 4]]
    var m = [[1, 2], [3, 4]]
    print(n == m, n < m)
    print(a[0], b[1], len(n))
