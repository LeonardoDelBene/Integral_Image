#include <iostream>
#include <vector>
#include <chrono>
#include <ctime>

using namespace std;
using namespace chrono;

// Funzione per calcolare l'Integral Image
vector<vector<int>> computeIntegralImage(const vector<vector<int>>& image) {
    int rows = image.size();
    int cols = image[0].size();
    vector<vector<int>> integral(rows, vector<int>(cols, 0));

    for (int i = 0; i < rows; i++) {
        for (int j = 0; j < cols; j++) {
            int top = (i > 0) ? integral[i - 1][j] : 0;
            int left = (j > 0) ? integral[i][j - 1] : 0;
            int topLeft = (i > 0 && j > 0) ? integral[i - 1][j - 1] : 0;

            integral[i][j] = image[i][j] + top + left - topLeft;
        }
    }
    return integral;
}

// Funzione per calcolare la somma in una regione rettangolare
int sumRegion(const vector<vector<int>>& integral, int x1, int y1, int x2, int y2) {
    int A = (x1 > 0 && y1 > 0) ? integral[x1 - 1][y1 - 1] : 0;
    int B = (y1 > 0) ? integral[x2][y1 - 1] : 0;
    int C = (x1 > 0) ? integral[x1 - 1][y2] : 0;
    int D = integral[x2][y2];

    return D - B - C + A;
}

vector<vector<int>> generateRandomMatrix(int rows, int cols, int maxVal = 255) {
    vector<vector<int>> matrix(rows, vector<int>(cols));
    srand(time(0));
    for (int i = 0; i < rows; i++) {
        for (int j = 0; j < cols; j++) {
            matrix[i][j] = rand() % (maxVal + 1);
        }
    }
    return matrix;
}


int main() {
    // Esempio di immagine 5x5
    vector<vector<int> > image = generateRandomMatrix(16384, 16384);
    /*for (int i = 0; i < image.size(); i++) {
        for (int j = 0; j < image[i].size(); j++) {
            cout << image[i][j] << " ";
        }
        cout << endl;
    }*/


    auto start = high_resolution_clock::now();
    // Calcolo dell'Integral Image
    vector<vector<int> > integral = computeIntegralImage(image);

    auto stop = high_resolution_clock::now();
    auto duration = duration_cast<milliseconds>(stop - start);
    cout << "Tempo di esecuzione: " << duration.count() << " ms" << endl;

    /*for (int i = 0; i < integral.size(); i++) {
        for (int j = 0; j < integral[i].size(); j++) {
            cout << integral[i][j] << " ";
        }
        cout << endl;
    }*/

    // Esempio di query: somma dei pixel nell'area (1,1) -> (3,3)
    int sum = sumRegion(integral, 1, 1, 3, 3);
    cout << "Somma della regione (1,1) -> (3,3): " << sum << endl;

    return 0;
}


