def nothing(k: Int):
    pass


def main():
    var xs = [nothing(1), nothing(2)]
    var ys = xs
    print(len(ys))
