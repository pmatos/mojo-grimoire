def h():
    var a: Array[Int, 2] = [1, 2]
    print(a[5])

def f():
    h()

def g():
    h()

def main():
    g()
    f()
