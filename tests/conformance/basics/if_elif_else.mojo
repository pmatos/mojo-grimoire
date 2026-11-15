def classify(n: Int) -> Int:
    if n < 0:
        return -1
    elif n == 0:
        return 0
    else:
        return 1


def main():
    print(classify(-5), classify(0), classify(9))
