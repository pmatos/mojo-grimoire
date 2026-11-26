def h():
    var a: Array[Int, 2] = [1, 2]
    print(a[3])


def k():
    var a: Array[Int, 2] = [1, 2]
    print(a[4])


def f():
    h()


def g():
    k()
    h()


def main():
    f()
    g()
