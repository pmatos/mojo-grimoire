def f():
    var xs: List[Int] = [1]
    ref r = xs[0]
    xs.append(2)
    print(r)

def g():
    var y: Int
    print(y)

def main():
    f()
    g()
