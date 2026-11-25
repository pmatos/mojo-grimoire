@fieldwise_init
struct P(Copyable):
    var x: Int

def main():
    var b: Bool
    var p = P(b)
    print(p.x)
