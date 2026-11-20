def same(ref x: Int) -> ref [x] Int:
    return x


def main():
    var y = 1
    var same = 0
    ref z = same(y)
    print(z, same)
