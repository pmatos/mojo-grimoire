def show(n: Int) -> Int:
    print("eval", n)
    return n


def grow(mut k: Int) -> Int:
    k = 9
    return 0


def main():
    var k = 7
    k[show(0)] = show(5)
    print(k)
    k[grow(k)] = k + 1
    print(k)
    k[0] = grow(k) + k
    print(k)
