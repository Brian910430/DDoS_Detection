/* -*- P4_16 -*- */
#include <core.p4>
#include <v1model.p4>

#include "include/headers-hyperloglog-16+countmin.p4"
#include "include/parsers.p4"

/* CONSTANTS */

/* Keep exact packet counter for comparison (for evaluation or debugging) */

#define KEEP_EXACT_PACKET_COUNT 1

/* HyperLogLog */

#define HYPERLOGLOG_NUM_REGISTERS_EXPONENT 4
#define HYPERLOGLOG_NUM_REGISTERS (1 << HYPERLOGLOG_NUM_REGISTERS_EXPONENT)
#define HYPERLOGLOG_REGISTER_INDEX_BIT_WIDTH HYPERLOGLOG_NUM_REGISTERS_EXPONENT
#define HYPERLOGLOG_CELL_BIT_WIDTH 5
#define HYPERLOGLOG_HASH_BIT_WIDTH 32
#define HYPERLOGLOG_HASH_VAL_BIT_WIDTH (HYPERLOGLOG_HASH_BIT_WIDTH - HYPERLOGLOG_REGISTER_INDEX_BIT_WIDTH)
#define HYPERLOGLOG_MAX_RHO (HYPERLOGLOG_HASH_BIT_WIDTH + 1 - HYPERLOGLOG_REGISTER_INDEX_BIT_WIDTH)
/*
 * Estimate must have at least 34 bits to accommodate whole range of possible results of the registers' sum:
 * The minimal summand is 2^(-(L + 1 - \log_2(m))). Therefore, for m = 16 and L = 32, 29 bits past the "point" are required.
 * The maximal sum is m * 2^0 = m. Therefore, for m = 16, 5 bits before the "point" are required.
 *
 * Additionally, largest estimate produced by small range correction is 35 bits long.
 *
 * Therefore, HYPERLOGLOG_ESTIMATE_BIT_WIDTH is 35.
 */
#define HYPERLOGLOG_ESTIMATE_BIT_WIDTH 35
#define HYPERLOGLOG_SMALL_RANGE_CORRECTION_THRESHOLD 2312410000 // 1/(2.5 * 16 / (0.673 * 16**2)) << 29
#define HYPERLOGLOG_DDOS_THRESHOLD 92496400 // equiv. to 1000, calculated as (1000/(0.673 * 16^2))^(-1) << 29

#define HYPERLOGLOG_REGISTER(num) register<bit<HYPERLOGLOG_CELL_BIT_WIDTH>>(HYPERLOGLOG_NUM_REGISTERS) hyperloglog_sketch##num

#define HLL_COUNT_ELSE_IF(n) else if ((bit<HYPERLOGLOG_HASH_VAL_BIT_WIDTH>)meta.hash_val_w[n:0] == meta.hash_val_w) { meta.rho = HYPERLOGLOG_HASH_BIT_WIDTH - HYPERLOGLOG_REGISTER_INDEX_BIT_WIDTH - n; } \

#define HYPERLOGLOG_COUNT(num, algorithm) hash(meta.hash_val_x, HashAlgorithm.algorithm, (bit<16>)0, \
 {hdr.ipv4.srcAddr}, (bit<32>)4294967295); \
 meta.register_index_j = meta.hash_val_x[(HYPERLOGLOG_REGISTER_INDEX_BIT_WIDTH-1):0]; \
 meta.hash_val_w = meta.hash_val_x[31:HYPERLOGLOG_REGISTER_INDEX_BIT_WIDTH]; \
 hyperloglog_sketch##num.read(meta.current_register_val_Mj, (bit<32>)meta.register_index_j); \
 if (meta.hash_val_x == 0) { meta.rho = HYPERLOGLOG_HASH_BIT_WIDTH - HYPERLOGLOG_REGISTER_INDEX_BIT_WIDTH + 1; } \
 HLL_COUNT_ELSE_IF(0) \
 HLL_COUNT_ELSE_IF(1) \
 HLL_COUNT_ELSE_IF(2) \
 HLL_COUNT_ELSE_IF(3) \
 HLL_COUNT_ELSE_IF(4) \
 HLL_COUNT_ELSE_IF(5) \
 HLL_COUNT_ELSE_IF(6) \
 HLL_COUNT_ELSE_IF(7) \
 HLL_COUNT_ELSE_IF(8) \
 HLL_COUNT_ELSE_IF(9) \
 HLL_COUNT_ELSE_IF(10) \
 HLL_COUNT_ELSE_IF(11) \
 HLL_COUNT_ELSE_IF(12) \
 HLL_COUNT_ELSE_IF(13) \
 HLL_COUNT_ELSE_IF(14) \
 HLL_COUNT_ELSE_IF(15) \
 HLL_COUNT_ELSE_IF(16) \
 HLL_COUNT_ELSE_IF(17) \
 HLL_COUNT_ELSE_IF(18) \
 HLL_COUNT_ELSE_IF(19) \
 HLL_COUNT_ELSE_IF(20) \
 HLL_COUNT_ELSE_IF(21) \
 HLL_COUNT_ELSE_IF(22) \
 HLL_COUNT_ELSE_IF(23) \
 HLL_COUNT_ELSE_IF(24) \
 HLL_COUNT_ELSE_IF(25) \
 HLL_COUNT_ELSE_IF(26) \
 else { meta.rho = 1; } \
 if (meta.current_register_val_Mj < meta.rho) { \
    hyperloglog_sketch##num.write((bit<32>)meta.register_index_j, meta.rho); \
 }

#define HLL_EST_ADD_REGISTER(n) hyperloglog_sketch0.read(hll_value, n); \
 if (hll_value == 0) { hll_sum = hll_sum + (1 << HYPERLOGLOG_MAX_RHO); number_of_empty_registers = number_of_empty_registers + 1; } \
 else { hll_sum = hll_sum + (bit<HYPERLOGLOG_ESTIMATE_BIT_WIDTH>)(1 << (HYPERLOGLOG_MAX_RHO - hll_value)); }

 /* CountMin */

#define COUNTMIN_NUM_REGISTERS 28
#define COUNTMIN_CELL_BIT_WIDTH 64

#define COUNTMIN_DDOS_THRESHOLD 100000
#define ENABLE_HLL_THRESHOLD 5000

#define COUNTMIN_REGISTER(num) register<bit<COUNTMIN_CELL_BIT_WIDTH>>(COUNTMIN_NUM_REGISTERS) countmin_sketch##num

#define COUNTMIN_COUNT(num, algorithm) hash(meta.index_countmin_sketch##num, HashAlgorithm.algorithm, (bit<16>)0, {hdr.ipv4.dstAddr}, (bit<32>)COUNTMIN_NUM_REGISTERS);\
 countmin_sketch##num.read(meta.value_countmin_sketch##num, meta.index_countmin_sketch##num); \
 meta.value_countmin_sketch##num = meta.value_countmin_sketch##num +1; \
 countmin_sketch##num.write(meta.index_countmin_sketch##num, meta.value_countmin_sketch##num)

/*************************************************************************
************   C H E C K S U M    V E R I F I C A T I O N   *************
*************************************************************************/

control MyVerifyChecksum(inout headers hdr, inout metadata meta) {
    apply {  }
}

/*************************************************************************
**************  I N G R E S S   P R O C E S S I N G   *******************
*************************************************************************/

control MyIngress(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata) {

    /* For debugging or evaluation purposes */

#if KEEP_EXACT_PACKET_COUNT
    counter(1, CounterType.packets) packet_counter;
#endif

    /* For sketch rollover */

    // TODO Re-implement rollover
    /*register<bit<1>>(1) active_hyperloglog_sketch;
    register<bit<1>>(1) active_countmin_sketch;*/

    /* DDoS detection */

    register<bit<1>>(1) ddos_detected;

    register<bit<12>>(3) send_packet_cnt;
    register<bit<1>>(3) hyper_flag;
    register<bit<32>>(3) blacklist

    /* HyperLogLog */

    HYPERLOGLOG_REGISTER(0);
    HYPERLOGLOG_REGISTER(1);
    HYPERLOGLOG_REGISTER(2);

    /* CountMin */

    COUNTMIN_REGISTER(0);
    COUNTMIN_REGISTER(1);
    COUNTMIN_REGISTER(2);
    COUNTMIN_REGISTER(3);
    COUNTMIN_REGISTER(4);
    COUNTMIN_REGISTER(5);

    register<bit<64>>(1) countmin_est;

    action countmin_sketch0_count() {
        COUNTMIN_COUNT(0, crc32_custom);
        COUNTMIN_COUNT(1, crc32_custom);
        COUNTMIN_COUNT(2, crc32_custom);
    }

    action countmin_sketch1_count() {
        COUNTMIN_COUNT(3, crc32_custom);
        COUNTMIN_COUNT(4, crc32_custom);
        COUNTMIN_COUNT(5, crc32_custom);
    }

    /* DDoS detection actions */

    action sketch_thresholds_exceeded() {
        clone(CloneType.I2E, 100);
    }

    /* Basic switch actions */

    action drop() {
        mark_to_drop(standard_metadata);
    }

    action forward(bit<9> egress_port) {
        standard_metadata.egress_spec = egress_port;
    }

    table repeater {
        key = {
            standard_metadata.ingress_port: exact;
        }

        actions = {
            forward;
            NoAction;
        }
        size = 256;
        default_action = NoAction;
    }

    apply {
        if (hdr.ipv4.isValid()) { // 10.0.1.2
#if KEEP_EXACT_PACKET_COUNT
            /* Update packet counter */
            packet_counter.count(0);
#endif

            /* Update CountMin sketches */
            countmin_sketch0_count();
            countmin_sketch1_count();

            /* Get CountMin estimate */
            bit<64> countmin_result;
            if (meta.value_countmin_sketch0 <= meta.value_countmin_sketch1) {
                if (meta.value_countmin_sketch0 <= meta.value_countmin_sketch2) {
                    countmin_result = meta.value_countmin_sketch0;
                } else {
                    countmin_result = meta.value_countmin_sketch2;
                }
            } else {
                if (meta.value_countmin_sketch1 <= meta.value_countmin_sketch2) {
                    countmin_result = meta.value_countmin_sketch1;
                } else {
                    countmin_result = meta.value_countmin_sketch2;
                }
            }
            
            countmin_est.write(0, countmin_result);


	    bit<32> cmp1;
	    bit<32> cmp2;
	    bit<32> cmp3;

	    blacklist.read(cmp1, 0);
	    blacklist.read(cmp2, 1);
	    blacklist.read(cmp3, 2);

	    bit<12> cnt1;
	    bit<12> cnt2;
	    bit<12> cnt3;

	    if ( countmin_result > ENABLE_HLL_THRESHOLD && (hdr.ipv4.dstAddr == cmp1 || cmp1 == 0))
            {
 		send_packet_cnt.read(cnt1, 0);
		cnt1 = cnt1 + 1;
 		send_packet_cnt.write(0, cnt1);
		if (cmp1 == 0 || cnt1 == 1000)
		{
		    send_packet_cnt.write(0, 0);
		    hyper_flag.write(0, 1);
		    clone(CloneType.I2E, 100);
		}
		blacklist.write(0, hdr.ipv4.dstAddr);
                HYPERLOGLOG_COUNT(0, crc32_custom);
            }
	    else if ( countmin_result > ENABLE_HLL_THRESHOLD && (hdr.ipv4.dstAddr == cmp2 || cmp2 == 0))
            {
	        send_packet_cnt.read(cnt2, 1);
		cnt2 = cnt2 + 1;
 		send_packet_cnt.write(1, cnt2);
		if (cmp2 == 0 || cnt2 == 1000)
		{
		    send_packet_cnt.write(1, 0);
		    hyper_flag.write(1, 1);
		    clone(CloneType.I2E, 100);
		}
		blacklist.write(1, hdr.ipv4.dstAddr);
                HYPERLOGLOG_COUNT(1, crc32_custom);            
            }
	    else if ( countmin_result > ENABLE_HLL_THRESHOLD && (hdr.ipv4.dstAddr == cmp3 || cmp3 == 0))
            {
	        send_packet_cnt.read(cnt3, 2);
		cnt3 = cnt3 + 1;
 		send_packet_cnt.write(2, cnt3);
		if (cmp3 == 0 || cnt3 == 1000)
		{
		    send_packet_cnt.write(2, 0);
		    hyper_flag.write(2, 1);
		    clone(CloneType.I2E, 100);
		}
		blacklist.write(2, hdr.ipv4.dstAddr);
                HYPERLOGLOG_COUNT(2, crc32_custom);            
            }

        }
        repeater.apply();
    }
}

/*************************************************************************
****************  E G R E S S   P R O C E S S I N G   *******************
*************************************************************************/

control MyEgress(inout headers hdr,
                 inout metadata meta,
                 inout standard_metadata_t standard_metadata) {
    apply {
        // If ingress clone
        if (standard_metadata.instance_type == 1) {
            hdr.ethernet.etherType = 0x1234; // used by controller to filter packets
        }
    }
}

/*************************************************************************
*************   C H E C K S U M    C O M P U T A T I O N   **************
*************************************************************************/

control MyComputeChecksum(inout headers hdr, inout metadata meta) {
     apply {
    }
}

/*************************************************************************
***********************  S W I T C H  *******************************
*************************************************************************/

//switch architecture
V1Switch(
MyParser(),
MyVerifyChecksum(),
MyIngress(),
MyEgress(),
MyComputeChecksum(),
MyDeparser()
) main;
