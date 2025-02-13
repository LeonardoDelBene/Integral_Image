#include <iostream>
#include <vector>
#include <random>
#include <chrono>

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

// Funzione per generare una matrice casuale di dimensione n x m
vector<vector<int>> generateRandomMatrix(int n, int m) {
    vector<vector<int>> matrix(n, vector<int>(m));
    random_device rd;
    mt19937 gen(rd());
    uniform_int_distribution<> dis(0, 255);

    for (int i = 0; i < n; i++) {
        for (int j = 0; j < m; j++) {
            matrix[i][j] = dis(gen);
        }
    }
    return matrix;
}


int main() {
    const int N = 15000;
    const int M = 15000;

    // Generazione della matrice casuale
    vector<vector<int>> image = generateRandomMatrix(N, M);
    cout << "Matrice: " << N << "x" << M << endl;

    vector<long long> tempi;
    long long sommaTempi = 0;

    /*std::cout << "Matrice iniziale:" << std::endl;
    for (int i = 0; i < N; i++) {
        for (int j = 0; j < M; j++) {
            std::cout<< image[i][j] << " ";
        }
        std::cout << "\n";
    }*/

    // Eseguire l'algoritmo 10 volte
    for (int i = 0; i < 5; i++) {
        auto start = high_resolution_clock::now();

        vector<vector<int>> integral = computeIntegralImage(image);

        auto stop = high_resolution_clock::now();
        auto duration = duration_cast<milliseconds>(stop - start).count();

        tempi.push_back(duration);
        sommaTempi += duration;
        /*std::cout << "Matrice finale:" << std::endl;
        for (int i = 0; i < N; i++) {
            for (int j = 0; j < M; j++) {
                std::cout << integral[i][j] << " ";
            }
            std::cout << "\n";
        }*/

        cout << "Esecuzione " << i + 1 << ": " << duration << " ms" << endl;
    }

    // Calcolo della media
    double media = static_cast<double>(sommaTempi) / 10.0;
    cout << "Tempo medio: " << media << " ms" << endl;

    return 0;
}