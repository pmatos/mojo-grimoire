def f(b: Bool) -> Bool:
    return b


def main():
    var bs: List[Bool] = [False, True]
    print(bs[0] < bs[1], f(True) >= bs[0], not bs[1] <= bs[0])
