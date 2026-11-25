def f():
    var xs: List[Int] = [1]
    print(xs[-1])

def g() -> Int:
    print(1)

def main():
    f()
    print(g())
