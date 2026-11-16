def main():
    var xss: List[List[Int]] = [[1], [0, 7]]
    print(xss[1].pop(len(xss.pop()) - 1))
