#include <iostream>
#include <random>
#include <cuda_runtime.h>
#include <chrono>
#include <vector>
#include <algorithm>

using namespace std;
using namespace chrono;

#define N 10000 // Numero di righe della matrice
#define M 10000 // Numero di colonne della matrice
#define BLOCK_SIZE 1024

__global__ void scan_kernel(int *d_in, int *d_out, int *block_sums, int m) {
    extern __shared__ int temp[];
    int idx = threadIdx.x + blockIdx.x * blockDim.x;
    int tid = threadIdx.x;


    if (idx < m) {
        temp[tid] = d_in[idx];
    } else {
        temp[tid] = 0;
    }
    __syncthreads();

    // Up-sweep
    for (int offset = 1; offset < blockDim.x; offset *= 2) {
        int index = (tid + 1) * offset * 2 - 1;
        __syncthreads();
        if (index < blockDim.x) {
            temp[index] += temp[index - offset];
        }
    }

    // Down-sweep
    for (int offset = blockDim.x / 2; offset > 0; offset /= 2) {
        int index = (tid + 1) * offset * 2 - 1;
        __syncthreads();
        if (index + offset < blockDim.x) {
            temp[index + offset] += temp[index];
        }
    }
    __syncthreads();


    if (tid == blockDim.x - 1) {
        block_sums[blockIdx.x] = temp[tid];
    }


    if (idx < m) {
        d_out[idx] = temp[tid];
    }
}

__global__ void scan_block_sums_kernel(int *d_block_sums, int num_blocks) {
    extern __shared__ int temp[];
    int tid = threadIdx.x;

    if (tid < num_blocks) {
        temp[tid] = d_block_sums[tid];
    }
    __syncthreads();


    for (int offset = 1; offset < num_blocks; offset *= 2) {
        int val = 0;
        if (tid >= offset) {
            val = temp[tid - offset];
        }
        __syncthreads();
        if (tid >= offset) {
            temp[tid] += val;
        }
        __syncthreads();
    }

    if (tid < num_blocks) {
        d_block_sums[tid] = temp[tid];
    }
}

__global__ void add_block_sums(int *d_out, int *block_sums_scanned, int m) {
    int idx = threadIdx.x + blockIdx.x * blockDim.x;
    if (blockIdx.x > 0 && idx < m) {
        d_out[idx] += block_sums_scanned[blockIdx.x - 1];
    }
}


__global__ void transpose_kernel(int* d_in, int* d_out, int n, int m) {
    int row = blockIdx.y * blockDim.y + threadIdx.y;
    int col = blockIdx.x * blockDim.x + threadIdx.x;

    if (row < n && col < m) {
        d_out[col * n + row] = d_in[row * m + col];
    }
}

void scan_matrix(int* h_mat, int n, int m) {
    int *d_mat, *d_out, *d_block_sums, *d_block_sums_scanned;
    int blockSize = BLOCK_SIZE;
    int numBlocks = (m + blockSize - 1) / blockSize;


    cudaMalloc((void**)&d_mat, n * m * sizeof(int));
    cudaMalloc((void**)&d_out, n * m * sizeof(int));
    cudaMalloc((void**)&d_block_sums, numBlocks * sizeof(int));
    cudaMalloc((void**)&d_block_sums_scanned, numBlocks * sizeof(int));

    cudaMemcpy(d_mat, h_mat, n * m * sizeof(int), cudaMemcpyHostToDevice);

    for (int i = 0; i < n; i++) {
        int row_offset = i * m;

        // Esegui lo scan della riga
        scan_kernel<<<numBlocks, blockSize, blockSize * sizeof(int)>>>(d_mat + row_offset, d_out + row_offset, d_block_sums, m);
        cudaDeviceSynchronize();



        // Esegui lo scan sui block sums
        scan_block_sums_kernel<<<1, blockSize, numBlocks * sizeof(int)>>>(d_block_sums, numBlocks);
        cudaDeviceSynchronize();

        // Aggiungi i prefix sum dei blocchi alla riga
        add_block_sums<<<numBlocks, blockSize>>>(d_out + row_offset, d_block_sums, m);
        cudaDeviceSynchronize();
    }


    cudaMemcpy(h_mat, d_out, n * m * sizeof(int), cudaMemcpyDeviceToHost);


    cudaFree(d_mat);
    cudaFree(d_out);
    cudaFree(d_block_sums);
    cudaFree(d_block_sums_scanned);

}




void transpose_matrix(int* h_mat, int* h_transposed, int n, int m) {
    int *d_mat, *d_transposed;

    cudaMalloc((void**)&d_mat, n * m * sizeof(int));
    cudaMalloc((void**)&d_transposed, m * n * sizeof(int));


    cudaMemcpy(d_mat, h_mat, n * m * sizeof(int), cudaMemcpyHostToDevice);


    dim3 blockDim(BLOCK_SIZE, BLOCK_SIZE);
    dim3 gridDim((m + BLOCK_SIZE - 1) / BLOCK_SIZE, (n + BLOCK_SIZE - 1) / BLOCK_SIZE);
    transpose_kernel<<<gridDim, blockDim>>>(d_mat, d_transposed, n, m);


    cudaMemcpy(h_transposed, d_transposed, m * n * sizeof(int), cudaMemcpyDeviceToHost);


    cudaFree(d_mat);
    cudaFree(d_transposed);
}


int main() {
    vector<int> h_mat(static_cast<size_t>(N) * static_cast<size_t>(M));
    vector<int> transposed_mat(static_cast<size_t>(M) * static_cast<size_t>(N));

    // Creazione del generatore di numeri casuali
    random_device rd;
    mt19937 gen(rd());
    uniform_int_distribution<> dis(0, 255);

    // Inizializza la matrice con numeri casuali
    for (int i = 0; i < N; i++) {
        for (int j = 0; j < M; j++) {
            h_mat[i * M + j] = dis(gen);
        }
    }
    /*std::cout << "Matrice iniziale:" << std::endl;
    for (int i = 0; i < N; i++) {
        for (int j = 0; j < M; j++) {
            std::cout << h_mat[i * M + j] << " ";
        }
        std::cout << "\n";
    }*/
    std::cout << "Matrice di dimensione " << N << "x" << M << std::endl;
    auto start = high_resolution_clock::now();

    scan_matrix(h_mat.data(), N, M);
    cudaDeviceSynchronize();

    transpose_matrix(h_mat.data(), transposed_mat.data(), N, M);
    cudaDeviceSynchronize();

    scan_matrix(transposed_mat.data(), M, N);
    cudaDeviceSynchronize();

    transpose_matrix(transposed_mat.data(), h_mat.data(), M, N);
    cudaDeviceSynchronize();

    auto stop = high_resolution_clock::now();
    auto duration = duration_cast<milliseconds>(stop - start).count();

    /*std::cout << "\nMatrice finale:" << std::endl;
    for (int i = 0; i < N; i++) {
        for (int j = 0; j < M; j++) {
            std::cout << h_mat[i * M + j] << " ";
        }
        std::cout << "\n";
    }*/
    cout << "\nTempo di esecuzione: " << duration << " ms" << endl;

    return 0;
}
