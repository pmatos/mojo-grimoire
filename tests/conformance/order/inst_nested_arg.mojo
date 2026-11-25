def f(x: Int):
    var a: Array[Int, 2] = [1, 2]
    print(a[3])


def g() -> Int:
    var a: Array[Int, 2] = [1, 2]
    print(a[4])
    return 1


def main():
    f(g())
