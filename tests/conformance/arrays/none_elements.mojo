def nothing(k: Int):
    pass


def main():
    var xs = [nothing(1), nothing(2)]
    var first = xs[0]
    xs[1] = nothing(3)
    var nested = [[nothing(4)], [nothing(5)]]
    var ys = xs.copy()
    print(len(xs), len(nested), len(ys))
