def main():
    var grid: List[List[Int]] = [[1], [2]]
    grid[0] = List[Int](grid[1])
    grid[1] = List[Int](grid[1])
    grid[0].append(3)
    print(grid)
