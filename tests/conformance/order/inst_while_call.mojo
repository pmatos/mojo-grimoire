def f():
    var a: Array[Int, 2] = [1, 2]
    print(a[3])


def g():
    var a: Array[Int, 2] = [1, 2]
    print(a[4])


def main():
    var n = 1
    while n > 0:
        f()
        n -= 1
    g()
