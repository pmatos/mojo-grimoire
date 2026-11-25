def h():
    var a: Array[Int, 2] = [1, 2]
    print(a[5])

def f():
    h()

def g():
    var a: Array[Int, 2] = [1, 2]
    print(a[3])

def main():
    f()
    g()
