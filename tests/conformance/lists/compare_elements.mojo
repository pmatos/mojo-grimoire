def main():
    var xss: List[List[Int]] = [[1], [1]]
    print(xss[0] == xss[1])
    xss[0].append(2)
    print(xss[0] == xss[1], xss[0] != [1, 2])
