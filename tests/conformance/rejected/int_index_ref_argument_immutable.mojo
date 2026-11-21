def same(ref a: Int) -> ref [a] Int:
    return a


def main():
    var k = 7
    ref r = same(k[0])
    r = 3
    print(k)
