//OPIS: tri parametra i poziv 
//RETURN: 16

int x;
int y; 

int f1(int a, int b, int c) {
    x = a - b - c;
    return x;
}

int f2(int a) {
    y = a + 1;
    return y;
}

int main() {
  int a;
  int b;
  a = f1(30,15,12);
  b = f2(12);
  return a + b ;
}

