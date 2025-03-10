/*
 * Copyright (c) 2023, NVIDIA CORPORATION.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#include <test_utils.hpp>

#include <cuco/detail/__config>
#include <cuco/hash_functions.cuh>

#include <thrust/device_vector.h>

#include <catch2/catch_template_test_macros.hpp>
#include <catch2/catch_test_macros.hpp>

#include <cstddef>

template <int32_t Words>
struct large_key {
  constexpr __host__ __device__ large_key(int32_t value) noexcept
  {
    for (int32_t i = 0; i < Words; ++i) {
      data_[i] = value;
    }
  }

 private:
  int32_t data_[Words];
};

template <typename Hash>
__host__ __device__ bool check_hash_result(typename Hash::argument_type const& key,
                                           typename Hash::result_type seed,
                                           typename Hash::result_type expected) noexcept
{
  Hash h(seed);
  return (h(key) == expected);
}

template <typename OutputIter>
__global__ void check_hash_result_kernel_64(OutputIter result)
{
  int i = 0;

  result[i++] = check_hash_result<cuco::xxhash_64<char>>(0, 0, 16804241149081757544);
  result[i++] = check_hash_result<cuco::xxhash_64<char>>(42, 0, 765293966243412708);
  result[i++] = check_hash_result<cuco::xxhash_64<char>>(0, 42, 9486749600008296231);

  result[i++] = check_hash_result<cuco::xxhash_64<int32_t>>(0, 0, 4246796580750024372);
  result[i++] = check_hash_result<cuco::xxhash_64<int32_t>>(0, 42, 3614696996920510707);
  result[i++] = check_hash_result<cuco::xxhash_64<int32_t>>(42, 0, 15516826743637085169);
  result[i++] = check_hash_result<cuco::xxhash_64<int32_t>>(123456789, 0, 9462334144942111946);

  result[i++] = check_hash_result<cuco::xxhash_64<int64_t>>(0, 0, 3803688792395291579);
  result[i++] = check_hash_result<cuco::xxhash_64<int64_t>>(0, 42, 13194218611613725804);
  result[i++] = check_hash_result<cuco::xxhash_64<int64_t>>(42, 0, 13066772586158965587);
  result[i++] = check_hash_result<cuco::xxhash_64<int64_t>>(123456789, 0, 14662639848940634189);

#if defined(CUCO_HAS_INT128)
  result[i++] = check_hash_result<cuco::xxhash_64<__int128>>(123456789, 0, 7986913354431084250);
#endif

  result[i++] =
    check_hash_result<cuco::xxhash_64<large_key<32>>>(123456789, 0, 2031761887105658523);
}

TEST_CASE("Test cuco::xxhash_64", "")
{
  // Reference hash values were computed using https://github.com/Cyan4973/xxHash
  SECTION("Check if host-generated hash values match the reference implementation.")
  {
    CHECK(check_hash_result<cuco::xxhash_64<char>>(0, 0, 16804241149081757544));
    CHECK(check_hash_result<cuco::xxhash_64<char>>(42, 0, 765293966243412708));
    CHECK(check_hash_result<cuco::xxhash_64<char>>(0, 42, 9486749600008296231));

    CHECK(check_hash_result<cuco::xxhash_64<int32_t>>(0, 0, 4246796580750024372));
    CHECK(check_hash_result<cuco::xxhash_64<int32_t>>(0, 42, 3614696996920510707));
    CHECK(check_hash_result<cuco::xxhash_64<int32_t>>(42, 0, 15516826743637085169));
    CHECK(check_hash_result<cuco::xxhash_64<int32_t>>(123456789, 0, 9462334144942111946));

    CHECK(check_hash_result<cuco::xxhash_64<int64_t>>(0, 0, 3803688792395291579));
    CHECK(check_hash_result<cuco::xxhash_64<int64_t>>(0, 42, 13194218611613725804));
    CHECK(check_hash_result<cuco::xxhash_64<int64_t>>(42, 0, 13066772586158965587));
    CHECK(check_hash_result<cuco::xxhash_64<int64_t>>(123456789, 0, 14662639848940634189));

#if defined(CUCO_HAS_INT128)
    CHECK(check_hash_result<cuco::xxhash_64<__int128>>(123456789, 0, 7986913354431084250));
#endif

    // 32*4=128-byte key to test the pipelined outermost hashing loop
    CHECK(check_hash_result<cuco::xxhash_64<large_key<32>>>(123456789, 0, 2031761887105658523));
  }

  SECTION("Check if device-generated hash values match the reference implementation.")
  {
    thrust::device_vector<bool> result(10);

    check_hash_result_kernel_64<<<1, 1>>>(result.begin());

    CHECK(cuco::test::all_of(result.begin(), result.end(), [] __device__(bool v) { return v; }));
  }
}

template <typename OutputIter>
__global__ void check_hash_result_kernel_32(OutputIter result)
{
  int i = 0;

  result[i++] = check_hash_result<cuco::xxhash_32<char>>(0, 0, 3479547966);
  result[i++] = check_hash_result<cuco::xxhash_32<char>>(42, 0, 3774771295);
  result[i++] = check_hash_result<cuco::xxhash_32<char>>(0, 42, 2099223482);

  result[i++] = check_hash_result<cuco::xxhash_32<int32_t>>(0, 0, 148298089);
  result[i++] = check_hash_result<cuco::xxhash_32<int32_t>>(0, 42, 2132181312);
  result[i++] = check_hash_result<cuco::xxhash_32<int32_t>>(42, 0, 1161967057);
  result[i++] = check_hash_result<cuco::xxhash_32<int32_t>>(123456789, 0, 2987034094);

  result[i++] = check_hash_result<cuco::xxhash_32<int64_t>>(0, 0, 3736311059);
  result[i++] = check_hash_result<cuco::xxhash_32<int64_t>>(0, 42, 1076387279);
  result[i++] = check_hash_result<cuco::xxhash_32<int64_t>>(42, 0, 2332451213);
  result[i++] = check_hash_result<cuco::xxhash_32<int64_t>>(123456789, 0, 1561711919);

#if defined(CUCO_HAS_INT128)
  result[i++] = check_hash_result<cuco::xxhash_32<__int128>>(123456789, 0, 1846633701);
#endif

  result[i++] = check_hash_result<cuco::xxhash_32<large_key<32>>>(123456789, 0, 3715432378);
}

TEST_CASE("Test cuco::xxhash_32", "")
{
  // Reference hash values were computed using https://github.com/Cyan4973/xxHash
  SECTION("Check if host-generated hash values match the reference implementation.")
  {
    CHECK(check_hash_result<cuco::xxhash_32<char>>(0, 0, 3479547966));
    CHECK(check_hash_result<cuco::xxhash_32<char>>(42, 0, 3774771295));
    CHECK(check_hash_result<cuco::xxhash_32<char>>(0, 42, 2099223482));

    CHECK(check_hash_result<cuco::xxhash_32<int32_t>>(0, 0, 148298089));
    CHECK(check_hash_result<cuco::xxhash_32<int32_t>>(0, 42, 2132181312));
    CHECK(check_hash_result<cuco::xxhash_32<int32_t>>(42, 0, 1161967057));
    CHECK(check_hash_result<cuco::xxhash_32<int32_t>>(123456789, 0, 2987034094));

    CHECK(check_hash_result<cuco::xxhash_32<int64_t>>(0, 0, 3736311059));
    CHECK(check_hash_result<cuco::xxhash_32<int64_t>>(0, 42, 1076387279));
    CHECK(check_hash_result<cuco::xxhash_32<int64_t>>(42, 0, 2332451213));
    CHECK(check_hash_result<cuco::xxhash_32<int64_t>>(123456789, 0, 1561711919));

#if defined(CUCO_HAS_INT128)
    CHECK(check_hash_result<cuco::xxhash_32<__int128>>(123456789, 0, 1846633701));
#endif

    // 32*4=128-byte key to test the pipelined outermost hashing loop
    CHECK(check_hash_result<cuco::xxhash_32<large_key<32>>>(123456789, 0, 3715432378));
  }

  SECTION("Check if device-generated hash values match the reference implementation.")
  {
    thrust::device_vector<bool> result(20, true);

    check_hash_result_kernel_32<<<1, 1>>>(result.begin());

    CHECK(cuco::test::all_of(result.begin(), result.end(), [] __device__(bool v) { return v; }));
  }
}

TEMPLATE_TEST_CASE_SIG("Static vs. dynamic key hash test",
                       "",
                       ((typename Hash), Hash),
                       (cuco::murmurhash3_32<char>),
                       (cuco::murmurhash3_32<int32_t>),
                       (cuco::xxhash_32<char>),
                       (cuco::xxhash_32<int32_t>),
                       (cuco::xxhash_64<char>),
                       (cuco::xxhash_64<int32_t>))
{
  using key_type = typename Hash::argument_type;

  Hash hash;
  key_type key = 42;

  SECTION("Identical keys with static and dynamic key size should have the same hash value.")
  {
    CHECK(hash(key) ==
          hash.compute_hash(reinterpret_cast<std::byte const*>(&key), sizeof(key_type)));
  }
}