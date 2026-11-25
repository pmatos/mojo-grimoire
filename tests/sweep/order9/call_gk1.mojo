def two(mut a: Int, mut b: Int):
    a += 1
    b += 10
def mf(mut a: Int, ref b: Int):
    a += 10
    print(b)
def main():
    var k = 7
    two(k[0], k)
