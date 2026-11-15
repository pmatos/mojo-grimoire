def push_twice(mut xs: List[Int], v: Int):
    xs.append(v)
    xs.append(v)


def main():
    var xs: List[Int] = [0]
    push_twice(xs, 5)
    print(len(xs), xs[2])
