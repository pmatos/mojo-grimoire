def g():
    var a: Array[Int, 2] = [1, 2]
    print(a[4])

def f():
    g()
    var a: Array[Int, 2] = [1, 2]
    print(a[3])

def main():
    f()
