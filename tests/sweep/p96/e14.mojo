def h():
    var a: Array[Int, 2] = [1, 2]
    print(a[5])

def f():
    var a: Array[Int, 2] = [1, 2]
    print(a[3])

def g():
    h()

def main():
    f()
    g()
