// sycl_mpi_gather.cpp

#include <mpi.h>
#include <sycl/sycl.hpp>
#include <cstdlib>
#include <iostream>

int main(int argc, char **argv)
{
    MPI_Init(&argc, &argv);
    int rank, nranks;
    MPI_Comm_rank(MPI_COMM_WORLD, &rank);
    MPI_Comm_size(MPI_COMM_WORLD, &nranks);
    if (argc != 2) {
        std::cerr << "Usage: " << argv[0] << " <message_size_bytes>\n";
        MPI_Finalize();
        return 1;
    }

    size_t size = std::stoul(argv[1]);
    // Select a GPU.
    sycl::queue q{sycl::gpu_selector_v};
    char *sendbuf = sycl::malloc_device<char>(size, q);
    char *recvbuf = nullptr;
    if (rank == 0)
        recvbuf = sycl::malloc_device<char>(size * nranks, q);

    if (!sendbuf || (rank == 0 && !recvbuf)) {
        std::cerr << "Rank " << rank << ": GPU allocation failed\n";
        MPI_Abort(MPI_COMM_WORLD, 1);
    }

    q.memset(sendbuf, rank & 0xff, size).wait();
    if (rank == 0)
        q.memset(recvbuf, 0, size * nranks).wait();
    MPI_Barrier(MPI_COMM_WORLD);

    int rc = MPI_Gather(sendbuf,size, MPI_CHAR,recvbuf, size,MPI_CHAR,0,MPI_COMM_WORLD);

    if (rc != MPI_SUCCESS) {
        char err[MPI_MAX_ERROR_STRING];
        int len = 0;
        MPI_Error_string(rc, err, &len);
        std::cerr << "Rank " << rank << ": MPI_Gather failed: "
                  << std::string(err, len) << "\n";
    }

    MPI_Barrier(MPI_COMM_WORLD);
    if (rank == 0 && rc == MPI_SUCCESS)
        std::cout << "MPI_Gather completed successfully\n";
    sycl::free(sendbuf, q);
    if (rank == 0)
        sycl::free(recvbuf, q);
    MPI_Finalize();
    return 0;
}

