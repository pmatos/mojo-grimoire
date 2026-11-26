def h():
    var a: Array[Int, 2] = [1, 2]
    print(a[3])


def k():
    var a: Array[Int, 2] = [1, 2]
    print(a[4])


def f():
    k()
    h()


def g():
    k()


def main():
    f()
    g()
