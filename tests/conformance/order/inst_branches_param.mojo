def main():
    var n = 3
    pick(n > 1)


def f():
    var a: Array[Int, 2] = [1, 2]
    print(a[3])


def g():
    var a: Array[Int, 2] = [1, 2]
    print(a[4])


def pick(c: Bool):
    if c:
        f()
    else:
        g()
