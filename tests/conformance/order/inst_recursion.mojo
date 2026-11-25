def f(n: Int):
    if n > 0:
        f(n - 1)
    g()


def g():
    var a: Array[Int, 2] = [1, 2]
    print(a[3])


def h():
    var a: Array[Int, 2] = [1, 2]
    print(a[4])


def main():
    h()
    f(2)
