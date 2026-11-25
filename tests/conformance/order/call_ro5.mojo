def ro(xs: List[Int]):
    xs.append(xs[0])

def main():
    var xs: List[Int] = [1]
    ro(xs)
