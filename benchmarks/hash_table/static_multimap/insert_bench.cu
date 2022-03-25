/*
 * Copyright (c) 2021, NVIDIA CORPORATION.
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

#include <random>

#include <nvbench/nvbench.cuh>
#include <thrust/device_vector.h>

#include <cuco/static_multimap.cuh>
#include <key_generator.hpp>

/**
 * @brief A benchmark evaluating multi-value `insert` performance:
 * - Total number of insertions: 100'000'000
 * - CG size: 8
 */
template <typename Key, typename Value, dist_type Dist, nvbench::int32_t Multiplicity>
std::enable_if_t<(sizeof(Key) == sizeof(Value)), void> nvbench_static_multimap_insert(
  nvbench::state& state,
  nvbench::type_list<Key, Value, nvbench::enum_type<Dist>, nvbench::enum_type<Multiplicity>>)
{
  auto const num_keys  = state.get_int64("NumInputs");
  auto const occupancy = state.get_float64("Occupancy");

  std::size_t const size = num_keys / occupancy;

  std::vector<Key> h_keys(num_keys);
  std::vector<cuco::pair_type<Key, Value>> h_pairs(num_keys);

  generate_keys<Dist, Multiplicity, Key>(h_keys.begin(), h_keys.end());

  for (auto i = 0; i < num_keys; ++i) {
    Key key           = h_keys[i];
    Value val         = h_keys[i];
    h_pairs[i].first  = key;
    h_pairs[i].second = val;
  }

  thrust::device_vector<cuco::pair_type<Key, Value>> d_pairs(h_pairs);

  state.add_element_count(num_keys, "NumKeys");

  state.exec(nvbench::exec_tag::sync | nvbench::exec_tag::timer,
             [&](nvbench::launch& launch, auto& timer) {
               cuco::static_multimap<Key, Value> map{size, -1, -1};

               // Use timers to explicitly mark the target region
               timer.start();
               map.insert(d_pairs.begin(), d_pairs.end(), launch.get_stream());
               timer.stop();
             });
}

template <typename Key, typename Value, dist_type Dist, nvbench::int32_t Multiplicity>
std::enable_if_t<(sizeof(Key) != sizeof(Value)), void> nvbench_static_multimap_insert(
  nvbench::state& state,
  nvbench::type_list<Key, Value, nvbench::enum_type<Dist>, nvbench::enum_type<Multiplicity>>)
{
  state.skip("Key should be the same type as Value.");
}

using key_type   = nvbench::type_list<nvbench::int32_t, nvbench::int64_t>;
using value_type = nvbench::type_list<nvbench::int32_t, nvbench::int64_t>;
using d_type =
  nvbench::enum_type_list<dist_type::GAUSSIAN, dist_type::GEOMETRIC, dist_type::UNIFORM>;

using multiplicity = nvbench::enum_type_list<1, 2, 4, 8, 16, 32, 64, 128, 256>;

NVBENCH_BENCH_TYPES(nvbench_static_multimap_insert,
                    NVBENCH_TYPE_AXES(key_type,
                                      value_type,
                                      nvbench::enum_type_list<dist_type::UNIFORM>,
                                      multiplicity))
  .set_name("staic_multimap_insert_uniform_multiplicity")
  .set_type_axes_names({"Key", "Value", "Distribution", "Multiplicity"})
  .set_max_noise(3)                            // Custom noise: 3%. By default: 0.5%.
  .add_int64_axis("NumInputs", {100'000'000})  // Total number of key/value pairs: 100'000'000
  .add_float64_axis("Occupancy", {0.8});

NVBENCH_BENCH_TYPES(nvbench_static_multimap_insert,
                    NVBENCH_TYPE_AXES(key_type, value_type, d_type, nvbench::enum_type_list<8>))
  .set_name("staic_multimap_insert_occupancy")
  .set_type_axes_names({"Key", "Value", "Distribution", "Multiplicity"})
  .set_max_noise(3)                            // Custom noise: 3%. By default: 0.5%.
  .add_int64_axis("NumInputs", {100'000'000})  // Total number of key/value pairs: 100'000'000
  .add_float64_axis("Occupancy", nvbench::range(0.1, 0.9, 0.1));