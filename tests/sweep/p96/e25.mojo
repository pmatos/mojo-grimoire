def k():
    var a: Array[Int, 2] = [1, 2]
    print(a[6])

def h():
    var a: Array[Int, 2] = [1, 2]
    print(a[5])

def f():
    h()
    k()

def g():
    var a: Array[Int, 2] = [1, 2]
    print(a[3])

def main():
    g()
    f()
