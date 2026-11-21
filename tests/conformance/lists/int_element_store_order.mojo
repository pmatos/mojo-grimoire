def seti(mut i: Int) -> Int:
    i = 2
    return 6


def show(n: Int) -> Int:
    print("eval", n)
    return n


def main():
    var xss: List[List[Int]] = [[], [3], [4]]
    var i = 1
    xss[i][0][0] = seti(i)
    print(xss)
    var yss: List[List[Int]] = [[], [3]]
    yss[show(1)][show(0)][show(0)] = show(6)
    print(yss)
