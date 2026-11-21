def bump(mut a: Array[Int, 2]) -> Int:
    a[0] = 9
    return 2


def main():
    var a = [1, 2]
    print(a == [[9], [bump(a)]])
    var b = [1, 2]
    var x = 1
    print([[x], [bump(b)]] == b)
