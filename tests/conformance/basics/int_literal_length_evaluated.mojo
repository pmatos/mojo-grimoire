def f(n: Int) -> Int:
    print("f", n)
    return n


def main():
    var x: Int = [f(1), f(2)]
    print(x)
